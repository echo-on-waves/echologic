class QuestionsController < StatementsController

  # action: my discussions page
  def my_discussions
    @page     = params[:page]  || 1
    
    discussions_not_paginated = Question.by_creator(current_user).by_creation
    
    session[:current_question] = discussions_not_paginated.map(&:id)
    
    @discussions = discussions_not_paginated.paginate(:page => @page, :per_page => 5)    
    @statement_documents = search_statement_documents(@discussions.map(&:statement_id),
                                                      @language_preference_list)
                  
    respond_to_js :template => 'statements/questions/my_discussions', :template_js => 'statements/questions/discussions'
  end


  # action: publish a statement
  def publish
    begin
      StatementNode.transaction do
        @statement_node.publish
        respond_to do |format|
          if @statement_node.save
            format.js do
              set_info("discuss.statements.published")
              render_with_info do |page|
                if params[:in] == 'summary'
                  page.redirect_to(url_for(@statement_node))
                else
                  @statement_documents =
                    search_statement_documents([@statement_node.statement_id])
                  page.replace(dom_id(@statement_node),
                               :partial => 'statements/questions/discussion',
                               :locals => {:discussion => @statement_node ,
                                           :statement_document => @statement_documents[@statement_node.statement_id]})
                end
              end
            end
          else
            format.js do
              show_error_messages(@statement_node)
            end
          end
        end
      end
    rescue Exception => e
      log_message_error(e, "Error publishing statement node '#{@statement_node.id}'.") do |format|
        if params[:in] == 'summary'
          format.html { flash_error and redirect_to url_for(@statement_node) }
        else
          format.html { flash_error and redirect_to my_discussions_url }
        end
      end
    else
      log_message_info("Statement node '#{@statement_node.id}' has been published sucessfully.")
    end
  end


  protected
  # return a possible parent, in this case question doesn't have a parent
  def parent
    nil
  end

  #returns the handled statement type symbol
  def statement_node_symbol
    :question
  end

  # returns the statement_node class, corresponding to the controllers name
  def statement_node_class
    Question
  end

  def root_symbol
    nil
  end
end
