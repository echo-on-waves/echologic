require 'singleton'

class ActivityTrackingService
  include Singleton

  attr_accessor :period, :charges, :counter

  def initialize
    @counter = -1
  end

  def update(*args)
    send(*args)
  end


  #########
  # Hooks #
  #########

  def supported(echoable, user)
    return if user.nil?
    subscription = echoable.subscriptions.find_by_subscriber_id(user.id) ||
                     Subscription.new(:subscriber => user, :subscriber_type => user.class.name,
                                      :subscribeable => echoable, :subscribeable_type => echoable.class.name)
    echoable.subscriptions << subscription if subscription.new_record?
    # When echoable is a proposal, then we must follow the main discussion too
    if !echoable.parent.nil?
      parent_subscription = echoable.parent.subscriptions.find_by_subscriber_id(user.id) ||
                       Subscription.new(:subscriber => user, :subscriber_type => user.class.name,
                                        :subscribeable => echoable.parent, :subscribeable_type => echoable.parent.class.name)
      user.subscriptions << parent_subscription if parent_subscription.new_record?
    end
  end

  def unsupported(echoable, user)
    return if user.nil?
    subscription = echoable.subscriptions.find_by_subscriber_id(user.id)
    echoable.subscriptions.delete(subscription) if subscription
    # When a proposal, then we must remove the discussion subscription in the case when no more sibling is around
    if !echoable.parent.nil?
      parent_subscription = user.subscriptions.find_by_subscribeable_id(echoable.parent_id)
      if (user.subscriptions.map(&:subscribeable_id) & echoable.parent.children_statements.map(&:id)).empty?
        user.subscriptions.delete(parent_subscription) if parent_subscription
      end
    end
  end
  
  def created(node)
    created_event(node)
  end

  def incorporated(echoable, user)
  end


  #################
  # Service logic #
  #################

  #
  # Creates an event for the newly created subscribeable object
  #
  def created_event(node)
    
    event_json = {
      :type => node.class.name.underscore.downcase,
      :id => node.id,
      :tags => node.topic_tags,
      :documents => set_titles_hash(node.statement_documents),
      :parent_documents => node.parent ? set_titles_hash(node.parent.statement_documents) : nil,
      :root_documents => (node.root and node.root != node.parent) ? set_titles_hash(node.root.statement_documents) : nil,
      :parent_id => node.parent_id || -1,
      :root_id => (!node.root_id.nil? and node.root_id != node.parent_id) ? node.root_id : -1,
      :parent_type => node.parent ? node.parent.class.name.underscore.downcase : nil
    }.to_json

    node.events << Event.new(:event => event_json,
                             :operation => node.parent.nil? ? "new" : "new_child",
                             :subscribeable_type => node.class.name,
                             :subscribeable => node.parent)
  end

  #
  # Manages the counter to calculate current charge and schedules the next job with it.
  #
  def enqueue_activity_tracking_job(current_charge = 0)

    # After restarting the process (on new deployment) the
    # counter is initialized with the first running charge.
    @counter = current_charge if @counter == -1

    # Enqueuing the next job
    @counter += 1
    Delayed::Job.enqueue ActivityTrackingJob.new(@counter % @charges), 0,
                         Time.now.utc.advance(:seconds => @period/@charges)
  end

  #
  # Actually executes the job, generates activity mails, sends them and schedules the next job.
  #
  def generate_activity_mails(current_charge)

    # Enqueuing the next job
    enqueue_activity_tracking_job(current_charge)

    # Calculating 'after time' to minimize timeframe errors due to long lasting processes
    # FIXME: correct solution should be to persist the last_notification time per user
    after_time = @period.ago.utc - 5.minutes  # with 5 minutes safety buffer (some events might be delivered twice)

    # Iterating over users in the current charge
    User.all(:conditions => ["(id % ?) = ? and activity_notification = 1", @charges, current_charge]).each do |recipient|

      # Collecting events
      events = Event.find_tracked_events(recipient, after_time)
      next if events.blank? #if there are no events to send per email, take the next user

      question_events = events.select{|e|JSON.parse(e.event)['type'] == 'question'}
      tag_counts = Hash.new
      question_events.each do |question|
        question_data = JSON.parse(question.event)
        question_data['tags'].each{|tag| tag_counts[tag] = tag_counts[tag] ? tag_counts[tag] + 1 : 1 }
      end
      events.sort! do |a,b|
        a_parsed = JSON.parse(a.event) ; b_parsed = JSON.parse(b.event)
        [a_parsed['root_id'],a_parsed['parent_id']] <=> [b_parsed['root_id'],b_parsed['parent_id']]
      end

      # Sending the mail
      send_activity_email(recipient, question_events, tag_counts, events - question_events)
    end
  end

  #
  # Sends an activity tracking E-Mail to the given recipient.
  #
  def send_activity_email(recipient, question_events, question_tags, events)
    puts "Send mail to:" + recipient.email
    mail = ActivityTrackingMailer.create_activity_tracking_email(recipient,question_events,question_tags,events)
    ActivityTrackingMailer.deliver(mail)
  end

  #handle_asynchronously :send_activity_email



  def set_titles_hash(documents)
    hash = Hash.new
    documents.each do |document|
      hash[document.language_id] = document.title
    end
    hash
  end
end