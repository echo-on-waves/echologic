# Filters added to this controller apply to all controllers in the application.
# Likewise, all the methods added will be available for all controllers.

class ApplicationController < ActionController::Base
  helper :all # include all helpers, all the time
  protect_from_forgery # See ActionController::RequestForgeryProtection for details

  # Catch access denied exception in the whole application and handle it.
  rescue_from 'Acl9::AccessDenied', :with => :access_denied
  rescue_from 'ActionController::InvalidAuthenticityToken', :with => :invalid_auth_token
  rescue_from 'ActionController::RoutingError', :with => :redirect_to_home

  # Initializes translate_routes
  before_filter :set_locale

  # session timeout
  before_filter :session_expiry

  # Set locale to the best fitting one
  def set_locale
    available = %w{en de es}
    I18n.locale = params[:locale] || request.compatible_language_from(available)
  end

  # Authlogic authentification filters
  filter_parameter_logging :password, :password_confirmation
  helper_method :current_user_session, :current_user

  # Set notice from the given i18n string.
  def set_notice(i18n)
    flash[:notice] = I18n.t(i18n)
  end

  before_filter CASClient::Frameworks::Rails::GatewayFilter
  before_filter :check_for_cas_user

  def check_for_cas_user
    logger.fatal "have casfilteruser: #{session[:casfilteruser].inspect}" if session[:casfilteruser]
    @user_session = UserSession.create(User.find_by_email(session[:cas_user])) if session[:cas_user]
  end

  # AJAX METHODS TO UPDATE THE PAGE AND DISPLAY INFO/ERROR MESSAGES

  # Sets the @info variable to the localisation given through the string
  def set_info(string, options = {})
    @info = I18n.t(string, options)
  end

  # Renders :updates a page with an a info message set by set_info.
  def render_with_info(message=@info)
    render :update do |page|
      page << "info('#{message}');" if message
      yield page if block_given?
    end
  end

  # Sets the @info variable for the flash object
  def flash_info
    flash[:notice] = @info
  end

  # Sets error to the given objects error message.
  # If it's a string then use it as localisation key, else
  # check if it's ActiveRecord object and use the error
  # method on it.
  def set_error(object, options = {})
    if object.kind_of?(String)
      @error = I18n.t(object, options)
    elsif object.class.kind_of?(ActiveRecord::Base.class) && object.errors.count > 0
      value = I18n.t('activerecord.errors.template.body')
      value += "<ul>"
      object.errors.each do |attr_name, message|
        value += "<li>#{message}</li>"
      end
      value += "</ul>"
      @error = value
    end
  end

  def show_error_message(string)
    render :update do |page|
      page << "error('#{string}');"
    end
  end

  # Get formatted error string from error partial for a given object, then show
  # it on the page object as an error message.
  def show_error_messages(object=nil)
    render :update do |page|
      if object.blank?
        message = @error
      else
        message = render(:partial => 'layouts/components/error', :locals => {:object => object})
      end
      page << "error('#{escape_javascript(message)}');"
    end
  end

  # Sets the @error variable for the flash object
  def flash_error
    flash[:error] = @error
  end


  # Helper method to do simple ajax replacements without writing a new template.
  # This small methods takes much complexness from the controllers.
  def replace_container(name, content)
    render :update do |page|
      page << "$('##{name}').replaceWith('#{escape_javascript(render(content))}');"
      yield page if block_given?
    end
  end

  # Helper method to do simple ajax replacements without writing a new template.
  # This small methods takes much complexness from the controllers.
  def replace_content(name, content)
    render :update do |page|
      page.replace_html name, content
    end
  end

  # Helper method to remove some identifier from the page.
  def remove_container(name)
    render :update do |page|
      page.remove name
    end
  end

  def requires_login
    render :update do |page|
    end
  end


  # PRIVATE SECTION
  private

    ####################
    # Session handling #
    ####################

    # Return current session if one exists
    def current_user_session
      return @current_user_session if defined?(@current_user_session)
      @current_user_session = UserSession.find
    end

  # Returns currently logged in user
  def current_user
    return @current_user if defined?(@current_user)
    @current_user = current_user_session && current_user_session.user
  end


    # Before filter used to define which controller actions require an active and valid user session.
  def require_user
    unless current_user
      respond_to do |format|
        format.html {
          flash[:notice] = I18n.t('authlogic.error_messages.must_be_logged_in_for_page')
          request.env["HTTP_REFERER"] ? redirect_to(:back) : redirect_to(root_path)
        }
        format.js {
          # rendering an ajax-request, we assume it's rather an action, than a certain page, that the user want to access
          @info = I18n.t('authlogic.error_messages.must_be_logged_in_for_action')
          render_with_info
        }
        format.js {
          # rendering an ajax-request, we assume it's rather an action, than a certain page, that the user want to access
          @info = I18n.t('authlogic.error_messages.must_be_logged_in_for_action')
          render_with_info
        }
      end
      return false
    end
  end

    # Checks that the user is NOT logged in.
  def require_no_user
    if current_user
      flash[:notice] = I18n.t('authlogic.error_messages.must_be_logged_out')
      respond_to do |format|
        format.html { redirect_to root_path }
        format.js do
          render :update do |page|
            page.redirect_to root_path
          end
        end
      end
    end
    return false
  end




    ##################################
    # General error handling methods #
    ##################################

  # If access is denied display warning and redirect to users_path
  # TODO localize access denied message
  def access_denied
    flash[:error] = I18n.t('activerecord.errors.messages.access_denied')
    redirect_to welcome_path
  end


    # Handles session expiry
  def session_expiry
    if current_user_session and session[:expiry_time] and session[:expiry_time] < Time.now
      expire_session!
    end
    session[:expiry_time] = MAX_SESSION_PERIOD.seconds.from_now
    return true
  end



  def current_language_key
    EnumKey.find_by_enum_name_and_code("languages", I18n.locale.to_s).id
  end

  def current_language_keys
    keys = [current_language_key].concat(current_user ? current_user.language_keys : []).uniq
  end

  # Called when the authentication token is invalid. It might happen if the user is anactive for a too long time
  # or in case of a CSRF attack.
  def invalid_auth_token
    expire_session!
  end

  # Expires and cleans up the user session.
  def expire_session!
    current_user_session.try(:destroy)
    reset_session
    if params[:controller] == 'users/user_session' && params[:action] == 'destroy'
      # still display logout message on logout.
      flash[:notice] = I18n.t('users.user_sessions.messages.logout_success')
    else
      flash[:notice] = I18n.t('users.user_sessions.messages.session_timeout')
    end
    redirect_to root_path
  end

  # Called when when a routing error occurs.
  def redirect_to_home
    redirect_to welcome_url
  end
end
