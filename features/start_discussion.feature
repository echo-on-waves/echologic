@discuss @editor
Feature: Start a question
  In order to start a proper question
  As an editor
  I want to create questions and add proposals to it

  # Firstly do it unpublished...
  @ok
  Scenario: Create a valid question as an editor
    Given there are no questions
      And I am logged in as "editor" with password "true"
      And I am on the discuss index
    When I follow "My Questions"
      And I follow "Create a new question"
      And I fill in the following:
        | question_statement_document_title | Is this a Question?   |
        | question_statement_document_text | Blablabla bla bla bla |
      And I choose "Set up at first and publish later"
      And I press "Save"
    Then I should see "Blablabla"
     And there should be one question

  @ok
  Scenario: Publish a question i created as an editor
    Given I am logged in as "editor" with password "true"
      And a "New" question in "echonomyjam"
      And I am on the Discuss Index
    When I go to the question
      And I follow "Release"
    Then I should not see "Release"

  @ok
  Scenario: Create an invalid question as an editor
    Given there are no questions
      And I am logged in as "editor" with password "true"
    When I go to create a question
      And I fill in the following:
        | question_statement_document_text | Blablabla bla bla bla |
      And I press "Save"
    # Todo: Maybe we should check the content of the error box as well
    Then there should be no questions
      And I should see an error message

  @ok
  Scenario: Add a proposal to a question as an editor (from ui)
    Given I am logged in as "editor" with password "true"
      And there is the first question
      And the question has no proposals
      And I am on the discuss index
    When I follow "Featured"
    When I follow "echonomyJAM"
      And I choose the first Question
      And I follow localized "discuss.statements.create_proposal_link"
      And I fill in the following:
        | proposal_statement_document_title | a proposal to propose some proposeworthy proposal data |
        | proposal_statement_document_text | nothing to propose yet...                              |
      And I press "Save"
    Then I should see "a proposal to propose some"
      And the question should have one proposal


  #Category tests: tests the existence of the 4 main categories
  Scenario: I want to see all categories
    Given I am logged in as "user" with password "true"
   	And I am on the discuss index
   	When I follow "Featured"
    Then I should see localized "discuss.topics.echonomyjam.name"
    Then I should see localized "discuss.topics.echocracy.name"
    Then I should see localized "discuss.topics.echo.name"


  @ok
  Scenario: Fail to add a proposal to a question with * tag
    Given I am logged in as "user" with password "true"
      And there is a question
      And the question has "*beer" for tags
      And I go to the question
      And I follow localized "discuss.statements.create_proposal_link"
    Then I should see localized "discuss.statements.read_only_permission"

  @ok
  Scenario: Image upload in an unpublished question
    Given I am logged in as "user" with password "true"
      And there is a question i have created
    When I go to the question
      And I follow "Change" within ".image_container"
    Then I should see "Upload Image"
      And I should see "Cancel"
      And I should see "Upload"
    Given I go to the welcome page
      And I follow "logout_button"
      And I am logged in as "ben" with password "benrocks"
    When I go to the question
      Then I should not see "Change"