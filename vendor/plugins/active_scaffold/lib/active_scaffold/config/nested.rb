module ActiveScaffold::Config
  class Nested < Base
    self.crud_type = :read

    def initialize(core_config)
      @core = core_config
      self.shallow_delete = self.class.shallow_delete
    end

    # global level configuration
    # --------------------------
    cattr_accessor :shallow_delete
    @@shallow_delete = false

    # instance-level configuration
    # ----------------------------
    attr_accessor :shallow_delete

    # Add a nested ActionLink
    def add_link(label, *models)
      options = models.extract_options!
      msg = "config.nested.add_link with multiple associations is deprecated."
      if models[0].is_a? Array
        msg += " Remove array" if models[0].size == 1
        ::ActiveSupport::Deprecation.warn(msg, caller)
        models.flatten!
      elsif models.size > 1
        ::ActiveSupport::Deprecation.warn(msg, caller)
      end
      options.merge! :label => label, :type => :member, :security_method => :nested_authorized?, :position => :after, :parameters => {:associations => models.join(' ')}
      options[:html_options] ||= {}
      options[:html_options][:class] = [options[:html_options][:class], models.join(' ')].compact.join(' ')
      @core.action_links.add('nested', options)
    end

    # the label for this Nested action. used for the header.
    attr_writer :label
    def label
      @label ? as_(@label) : as_(:add_existing_model, :model => @core.label)
    end

  end
end
