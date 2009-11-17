Given /^there are no questions$/ do
  Question.destroy_all
end

Then /^there should be no questions$/ do
  Question.count.should == 0
end

Then /^there should be one question$/ do
  Question.count.should == 1
end

When /^I post some valid question data$/ do
  When  "I fill in the following:
        | Question title  | Is this a Question?     |
        | Question text   | Blablabla bla bla bla   |"
  When "I press the \"Save\" button"
end

When /^I post some invalid question data$/ do
   When  "I fill in the following:
        | Question text   | Blablabla bla bla bla   |"
   When "I press the \"Save\" button"
end

Then /^I should see an error message$/ do
  Then "I should see a \"error box\""
end

Given /^there is a question "([^\"]*)"$/ do |title|
  @question = Question.find_by_title(title)
end

Given /^the question has no proposals$/ do
  @question.proposals.destroy_all
end

When /^I follow the create proposal link$/ do
  # Todo: Yet we still don't know how the create proposal link will once look
  When 'I follow the "create proposal" link within the "question" container '
end

When /^I follow the create improvement proposal link$/ do
  # Todo: Yet we still don't know how the create improvementproposal link will once look
  When 'I follow the "create improvement proposal" link within the "proposal" container '
end

When /^I post some valid proposal data$/ do
  When 'I post some valid question data'
end

When /^I post some valid improvement proposal data$/ do
  When 'I post some valid improvement proposal data'
end

Then /^the question should have one proposal$/ do
  @question.proposals.count.should >= 1
end

# Is it okay to give a condition in a 'Given' step?
Given /^the question has at least on proposal$/ do
  @question.proposals.count.should >= 1
  @proposal = @question.proposal.first
end

Then /^the proposal should have one improvementproposal$/ do
  @proposal.improvementproposals.should >= 1
end

Then /^I should not see the create proposal link$/ do
  Then 'I should not see the "create proposal" link within the "question" container'
end

# i leave this pending for now, as i'm not sure if we should test the related scenario here
# see Scenario: Add a proposal to a question as a user (directly)
When /^I post some valid proposal data for "([^\"]*)"$/ do |arg1|
  pending # express the regexp above with the code you wish you had
end
