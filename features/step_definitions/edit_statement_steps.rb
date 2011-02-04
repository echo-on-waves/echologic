Given /^there is a proposal created by a regular user$/ do
  # for some reason Proposal.all gives me a Improvement
  @proposal = StatementNode.all(:conditions => { :type => 'Proposal' }).select { |p| ! p.creator.has_role?(:editor) }.first
  @proposal.should_not == nil
end
