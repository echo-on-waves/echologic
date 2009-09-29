class Users::ProfileController < ApplicationController

  before_filter :require_user, :only => [:show, :edit, :update, :get_personal]
  
  access_control do
    allow logged_in, :to => [:show, :update, :edit, :get_personal]
  end

  # Shows details for the current user, this action is formaly known as
  # profile! ;)
  # TODO respond to js correctly
  def show
    @user = @current_user
    respond_to do |format|
      format.html
    end
  end

  # Edit the profile details through rendering the edit partial to the
  # corresponding part of the profiles page.
  def edit
    @user = @current_user
    render :update do |page|
      page.replace_html 'personal', :partial => 'edit'
    end
  end

  # Set the values from the edit form to the users attributes.
  def update
    @user = @current_user
    if @user.update_attributes(params[:user])
      respond_to do |format|
        format.html { redirect_to profile_path }
      end
    end
  end

  # Responds in JS wether with editing or with view partial.
  def get_personal(editable=false)
    @user = @current_user
    render :update do |page|
      page.replace_html 'personal', :partial => 'personal_information'
    end

#    respond_to do |format|
#      format.js do
#        render :update do |page|
#          page.replace_html 'personal', :partial => 'personal_information'
#        end
#      end
#    end
  end


end