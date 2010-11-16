class ContraArgumentsController < StatementsController
  
  protected
 
  #returns the handled statement type symbol
  def statement_node_symbol
    :contra_argument
  end

  # returns the statement_node class, corresponding to the controllers name
  def statement_node_class
    ContraArgument
  end
end