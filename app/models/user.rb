class User < ActiveRecord::Base
  include UserExtension::Echo
  acts_as_subscriber
  acts_as_extaggable :affections, :engagements, :expertises, :decision_makings

  has_many :web_addresses
  has_many :memberships
  has_many :spoken_languages, :order => 'level_id asc'

  has_many :reports, :foreign_key => 'suspect_id'

  named_scope :no_member, :conditions => { :memberships => nil }, :order => :email

  # Every user must have a profile. Profiles are destroyed with the user.
  has_one :profile
  delegate :avatar, :percent_completed, :full_name, :first_name, :first_name=, :last_name, :last_name=,
           :city, :city=, :country, :country=, :completeness, :calculate_completeness, :location, :to => :profile

  #last login language, important for the activity tracking email language when the user doesn't have anything set
  has_enumerated :last_login_language, :class_name => 'Language'

  # TODO uncomment attr_accessible :active if needed.
  #attr_accessible :active

  # Authlogic plugin to do authentication
  acts_as_authentic do |c|
#    c.logged_in_timeout = 10.minutes #1.hour
    c.validates_length_of_password_field_options = {:on => :update,
                                                    :minimum => 4,
                                                    :if => :has_no_credentials?}
    c.validates_length_of_password_confirmation_field_options = {:on => :update,
                                                                 :minimum => 4,
                                                                 :if => :has_no_credentials?}
  end

  # acl9 plugin to do authorization
  acts_as_authorization_subject
  acts_as_authorization_object

  # we need to make sure that either a password or openid gets set
  # when the user activates his account
  def has_no_credentials?
    self.crypted_password.blank? && self.openid_identifier.blank?
  end

  # Return true if user is activated.
  def active?
    active
  end

  # handy interfacing
  def is_author?(other)
    other.author == self
  end

  # permission
  def permits_authorship?
    self.authorship_permission == 1
  end

  # Signup process before activation: get login name and email, ensure to not
  # handle with sessions.
  def signup!(params)
    self.first_name = params[:user][:profile][:first_name]
    self.last_name  = params[:user][:profile][:last_name]
    self.email              = params[:user][:email]
    save_without_session_maintenance
  end

  # Returns the display name of the user
  # TODO Depricated. Use user.full_name
  #  Changed for mailer model - anywhere else used?
  def display_name()
    self.first_name + " " + self.last_name;
  end

  # Activation process. Set user active and add its password and openID and
  # save with session handling afterwards.
  def activate!(params)
    u = params[:user]
    self.active = true
    self.update_attributes(params[:user])
  end

  # Uses mailer to deliver activation instructions
  def deliver_activation_instructions!
    reset_perishable_token!
    mail = RegistrationMailer.create_activation_instructions(self)
    RegistrationMailer.deliver(mail)
  end

  # Uses mailer to deliver activation confirmation
  def deliver_activation_confirmation!
    reset_perishable_token!
    mail = RegistrationMailer.create_activation_confirmation(self)
    RegistrationMailer.deliver(mail)
  end

  # Send a password reset email through mailer
  def deliver_password_reset_instructions!
    reset_perishable_token!
    mail = RegistrationMailer.create_password_reset_instructions(self)
    RegistrationMailer.deliver(mail)
  end

  ##
  ## Scopes
  ##

  named_scope :active, :conditions => {:active => true}

  def self.newsletter_recipients
    self.active.scoped :conditions => {:newsletter_notification => true}
  end

  def self.activity_recipients
    self.active.scoped :conditions => {:activity_notification => true}
  end

  def self.drafting_recipients
    self.active.scoped :conditions => {:drafting_notification => true}
  end

  ##
  ## PERMISSIONS
  ##

  # the given `statement_node' is ignored for now, but we need it later
  # when we enable editing for users.
  def may_edit?
    has_role?(:editor) or has_role?(:admin)
  end

  def may_delete?(statement_node)
    has_role?(:admin)
  end

  # Returns true if the user has the topic editor privileges for the given tag (as a String).
  def is_topic_editor(tag_value)
    tag = Tag.find_by_value(tag_value)
    tag and self.has_role? :topic_editor, tag
  end

  # Gives users with the given E-Mail addresses 'topic_editor' rights for the given hash tags.
  def self.grant_topic_editor(emails, tags)
    emails.each do |email|
      user = User.find_by_email email
      if user.nil?
        puts "User with E-Mail '#{email}' cannot be found."
        next
      else
        user_name = "#{user.profile.full_name} (#{user.email})"
      end
      tags.each do |tag_value|
        tag = Tag.find_by_value tag_value
        if tag.nil?
          puts "Tag '#{tag_value}' doesn't exist."
          next
        end
        user.has_role! :topic_editor, tag
        puts "'#{user_name})' has become topic editor of '#{tag_value}'."
      end
      puts user.save ? "User '#{user_name}' has been saved sucessfully." :
                       "Error saving user '#{user_name}'."
    end
  end

  ##
  ## SPOKEN LANGUAGES
  ##

  #
  # Returns the default language to be used for the user (degrade chain: mother_tounge -> last_login_language -> EN).
  #
  def default_language
    lang = !mother_tongues.empty? ? mother_tongues.first : self.last_login_language
    lang ? lang : Language[:en]
  end

  def preferred_languages
    last_login_id = self.last_login_language_id.nil? ? Language[:en].id : self.last_login_language_id
    sorted_spoken_languages(:language_id).concat([last_login_id]).uniq.map{|id|Language[id]}
  end

  #
  # Returns an array with the language_ids of the users spoken languages in order of language levels
  # (from mother tongue to basic).
  #
  def sorted_spoken_languages(attr = :language_id)
    spoken_languages.sort{|sl1, sl2| sl1.level_key <=> sl2.level_key}.map(&attr)
  end

  #
  # Returns an array with the user's mother tongues.
  #
  def mother_tongues
    spoken_languages.select{|sp| sp.level.code == 'mother_tongue'}.collect(&:language)
  end

  #
  # Returns the languages the user speaks at least at the given level.
  #
  def speaks_language?(language, min_level = nil)
    spoken_languages_at_min_level(min_level).include?(language)
  end

  #
  # Returns the languages the user speaks at least at the given level.
  #
  def spoken_languages_at_min_level(min_level = nil)
    spoken_languages.select{|sp| min_level.nil? or sp.level_key <= LanguageLevel[min_level].key}.collect(&:language)
  end



  # Return the first membership. If none is set return empty-string.
  def first_membership
    return "" if memberships.blank?
    "#{memberships.first.organisation} - #{memberships.first.position}"
  end


  ###################
  # ADMIN FUNCTIONS #
  ###################

  #
  # Instructs to call delete_account instead of destroying the user itself.
  #
  def before_destroy
    puts "The user object cannot be destroyed. Please call 'user.delete_account()' instead."
    false
  end

  #
  # This method removes all personalized data but leaves the (empty) user object itself in order not to
  # invalidate all user echos.
  #
  def delete_account
    begin
      self.profile.destroy
      self.memberships.each(&:destroy)
      self.spoken_languages.each(&:destroy)
      self.tao_tags.each(&:destroy)
      self.web_addresses.each(&:destroy)
      self.save(false)
      self.reload
      old_email = self.email
      self.email = ""
      self.crypted_password = nil
      self.current_login_ip = nil
      self.last_login_ip = nil
      self.activity_notification = 0
      self.drafting_notification = 0
      self.newsletter_notification = 0
      self.active = 0
      self.save(false)
    rescue Exception => e
      puts "Error deleting user account:"
      puts e.backtrace
    else
      puts "User account with E-Mail address '#{old_email}' has been deleted..."
    end
  end

end
