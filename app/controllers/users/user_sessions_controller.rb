class Users::UserSessionsController < ApplicationController

  before_filter :require_no_user, :only => [:new, :create, :create_rpx]
  skip_before_filter :require_user, :only => [:new, :create, :create_rpx]

  def new
    session[:redirect_url] = request.referer
    @user_session = UserSession.new
    @user ||= User.new
    @to_show = "signin"
    render_static_new :template => 'users/users/new' do |format|
      format.js {render :template => 'users/users/new'}
    end
    
  end

  # TODO use redirect back or default! see application controller!
  def create
    redirect_url = session[:redirect_url] || root_path
    @user_session = UserSession.new(params[:user_session])
    respond_to do |format|
      if @user_session.save
        set_info 'users.user_sessions.messages.login_success'
        flash_info
        format.html { redirect_to redirect_url }
        format.js{
          render :update do |page|
            page.redirect_to redirect_url
          end
        }
      else
        set_error 'users.user_sessions.messages.login_failed'
        set_later_call signin_path
        format.html { flash_error and flash_later_call and redirect_to redirect_url }
        format.js{ render_with_error }
      end
    end
  end

  def create_rpx
    redirect_url = session[:redirect_url] || root_path
    rpx_helper = RpxHelper.new(ENV['ECHO_RPX_API_KEY'], "https://#{ENV['ECHO_RPX_APP_NAME']}", nil)
    token = params[:token]
    profile_info = rpx_helper.auth_info(token)
    identifier = profile_info['identifier']
    user = User.find_by_rpx_identifier(identifier)
    if user.nil?
      respond_to do |format|
        set_error 'users.user_sessions.messages.login_failed_rpx'
        set_later_call signin_path
        format.html { flash_error and flash_later_call and redirect_to redirect_url }
      end
    else
      @user_session = UserSession.new(user)
      respond_to do |format|
        if @user_session.save
          set_info 'users.user_sessions.messages.login_success'
          format.html { flash_info and redirect_to redirect_url }
        else
          set_error 'users.user_sessions.messages.login_failed'
          format.html { flash_error and redirect_to redirect_url }
        end
      end
    end
  end

  def destroy
    current_user.update_attributes(:last_login_language => Language[params[:locale]])
    current_user_session.destroy
    reset_session
    set_info 'users.user_sessions.messages.logout_success'
    flash_info and redirect_to root_path
  end
end
