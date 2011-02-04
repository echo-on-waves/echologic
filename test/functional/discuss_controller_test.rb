require 'test_helper'

class DiscussControllerTest < ActionController::TestCase
  # Replace this with your real tests.
  def setup
    #login_as :user
    @controller = DiscussController.new
    login_as :user
  end

  test "should get index without being logged on" do
    get :index
    assert_response :success
  end


  test "should get roadmap without being logged on" do
    get :roadmap
    assert_response :success
  end

  test "should cancel question update and redirect to question page" do
    statement_node = Question.first
    session[:last_statement_node] = statement_node.id
    get :cancel
    assert_redirected_to question_url(statement_node)
  end

  test "should cancel proposal update and redirect to proposal page" do
    statement_node = Proposal.first
    session[:last_statement_node] = statement_node.id
    get :cancel
    assert_redirected_to proposal_url(statement_node)
  end

  test "should cancel improvement update and redirect to improvement page" do
    statement_node = Improvement.first
    session[:last_statement_node] = statement_node.id
    get :cancel
    assert_redirected_to improvement_url(statement_node)
  end

end
