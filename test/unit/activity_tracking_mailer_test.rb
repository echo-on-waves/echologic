require 'test_helper'

class ActivityTrackingMailerTest < ActionMailer::TestCase

  def test_activity_tracking_mail_discussion
    user = users(:user)
    discussion_event = events(:event_test_discussion)
    discussion_events = [discussion_event]

    tags = {'#echonomyjam' => 1,'user' => 2}
    events = []
    id = JSON.parse(discussion_event.event)['id']
    en = Language['en']
    title = JSON.parse(discussion_event.event)['documents'][en.id]
    # Send the email, then test that it got queued
    email = ActivityTrackingMailer.deliver_activity_tracking_mail!(user,discussion_events,tags,events)
    assert !ActionMailer::Base.deliveries.empty?
    # Test the body of the sent email contains what we expect it to
    assert_equal [user.email], email.to
    assert_equal "echo - Activity Notifications", email.subject
    assert_match /echo - Activity Notifications/, email.encoded
    assert_match /There are <strong>1 new discussions<\/strong> since the last update:/, email.encoded
    assert_match /#{title}/, email.encoded
    assert_match /#{id}/, email.encoded
    assert_match /The new discussions are related the following topics:/, email.encoded
    assert_match /user/, email.encoded
    assert_match /(2)/, email.encoded
  end

  def test_activity_tracking_mail_proposal
    user = users(:user)
    discussion_events = []
    tags = {}
    proposal_event = events(:event_second_proposal)
    id = JSON.parse(proposal_event.event)['id']
    parent_id = JSON.parse(proposal_event.event)['parent_id']
    en = Language['en']
    title = JSON.parse(proposal_event.event)['documents'][en.id]
    events = [proposal_event]
    # Send the email, then test that it got queued
    email = ActivityTrackingMailer.deliver_activity_tracking_mail!(user,discussion_events,tags,events)
    assert !ActionMailer::Base.deliveries.empty?
    # Test the body of the sent email contains what we expect it to
    assert_equal [user.email], email.to
    assert_equal "echo - Activity Notifications", email.subject
    assert_match /echo - Activity Notifications/, email.encoded
    assert_match /#{Discussion.find(parent_id).document_in_preferred_language(Language['en']).title}/, email.encoded
    assert_match /#{id}/, email.encoded
    assert_match /#{title}/, email.encoded
  end

  def test_activity_tracking_mail_improvement_proposal
    user = users(:user)
    discussion_events = []
    tags = {}
    impro_proposal_event = events(:event_first_impro_proposal)
    id = JSON.parse(impro_proposal_event.event)['id']
    parent_id = JSON.parse(impro_proposal_event.event)['parent_id']
    root_id = JSON.parse(impro_proposal_event.event)['root_id']
    en = Language['en']
    title = JSON.parse(impro_proposal_event.event)['documents'][en.id]
    events = [impro_proposal_event]
    # Send the email, then test that it got queued
    email = ActivityTrackingMailer.deliver_activity_tracking_mail!(user,discussion_events,tags,events)
    assert !ActionMailer::Base.deliveries.empty?
    # Test the body of the sent email contains what we expect it to
    assert_equal [user.email], email.to
    assert_equal "echo - Activity Notifications", email.subject
    assert_match /echo - Activity Notifications/, email.encoded
    assert_match /#{Proposal.find(parent_id).document_in_preferred_language(Language['en']).title}/, email.encoded
    assert_match /#{Discussion.find(root_id).document_in_preferred_language(Language['en']).title}/, email.encoded
    assert_match /#{id}/, email.encoded
    assert_match /#{title}/, email.encoded
  end

end