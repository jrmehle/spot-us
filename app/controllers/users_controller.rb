class UsersController < ApplicationController
  include AuthenticatedSystem

  def new
    @user = User.new
  end

  def create
    delete_cookie :auth_token
    @user = User.new(params[:user])
    if @user.save
      unless @user.organization?
        @user.activate!
        self.current_user = @user
        create_current_login_cookie
        update_balance_cookie
        flash_and_redirect(:success, 'Welcome to Spot.Us!', root_path)
      else
        flash_and_redirect(:success, "Your account will be reviewed prior to approval. We'll get back to you as soon as possible.", root_path)
      end
    else
      if request.xhr?
        render :partial => 'sessions/header_form', :status => :unprocessable_entity
      else
        render :action => 'new', :status => :unprocessable_entity
      end
    end
  end

  def activate
    self.current_user = User.find_by_activation_code(params[:activation_code])
    if current_user
      current_user.activate!
      login_cookies
      handle_first_donation_for_non_logged_in_user
      handle_first_pledge_for_non_logged_in_user
      flash[:success] = "You have successfully activated your account - welcome to Spot.Us!"
      redirect_back_or_default('/')
    else
      flash[:error] = "Sorry, we were unable to find that activation code. Perhaps you have already activated your account?"
      redirect_to new_session_url
    end
  end

  def activation_email
  end

  def resend_activation
    user = User.find_by_email(params[:email])
    if user && !user.activated?
      Mailer.deliver_activation_email(user)
      flash[:success] = 'Great! We just sent you another email. Click the link to finish activating your account.'
    else
      flash[:error] = "Sorry, we couldn't find an account with that email address."
    end
    redirect_back_or_default('/')
  end

  def password
  end

  def reset_password
    if user = User.find_by_email(params[:email])
      user.reset_password!
      flash[:success] = 'Your password has been reset. Please check your email.'
      redirect_to new_session_url
    else
      flash[:error] = 'We did not recognize that email address. Please check your spelling.'
      render :action => 'password'
    end
  end
end


