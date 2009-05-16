class ApplicationController < ActionController::Base
  include HoptoadNotifier::Catcher
  filter_parameter_logging :password, :password_confirmation, :credit_card_number
  helper :all # include all helpers, all the time

  include AuthenticatedSystem
  include SslRequirement

  include BounceBots

  # cache_sweeper :home_sweeper, :except => [:index, :show]

  before_filter :can_create?, :only => [:new, :create]
  before_filter :can_edit?, :only => [:edit, :update, :destroy]
  before_filter :current_network

  map_resource :profile, :singleton => true, :class => "User", :find => :current_user

  protect_from_forgery

  def current_network
    subdomain = current_subdomain.downcase if current_subdomain
    @current_network ||= Network.find_by_name(subdomain)
  end

  protected

  def login_cookies
    create_current_login_cookie
    update_balance_cookie
  end

  def create_current_login_cookie
    set_cookie("current_user_full_name", {:value => current_user.full_name})
  end

  def can_create?
    true
  end

  def can_edit?
    true
  end

  def update_balance_cookie
    set_cookie("balance_text",  {:value => render_to_string(:partial => 'shared/balance')})
  end

  def set_cookie(name, options={})
    cookies[name.to_sym] = options.merge(:domain => DEFAULT_HOST)
  end
  
  def delete_cookie(name)
    cookies.delete(name.to_sym, :domain => DEFAULT_HOST)
  end

  def handle_first_donation_for_non_logged_in_user
    if session[:news_item_id] && session[:donation_amount]
      self.current_user.donations.create(:pitch_id => session[:news_item_id], :amount => session[:donation_amount])
      session[:news_item_id] = nil
      session[:donation_amount] = nil
    end
  end

  def handle_first_pledge_for_non_logged_in_user
    if session[:news_item_id] && session[:pledge_amount]
      self.current_user.pledges.create(:tip_id => session[:news_item_id], :amount => session[:pledge_amount])
      session[:news_item_id] = nil
      session[:pledge_amount] = nil
    end
  end

  helper_method :url_for_news_item
  def url_for_news_item(news_item)
    case news_item
    when Pitch
      pitch_path(news_item)
    when Tip
      tip_path(news_item)
    when Story
      story_path(news_item)
    end
  end

  def store_comment_for_non_logged_in_user
    title, body, commentable_id = params_for_comment(params)
    if title && body && commentable_id
      session[:return_to] = url_for_news_item(NewsItem.find_by_id(params[:commentable_id]))
      session[:title] = title
      session[:body] = body
      session[:news_item_id] = commentable_id
    end
  end

  def params_for_comment(comment_params)
    comment_params.symbolize_keys!
    if comment_params[:comment]
      comment_params[:comment].symbolize_keys!
      [comment_params[:comment][:title], comment_params[:comment][:body], comment_params[:commentable_id]]
    else
      [comment_params[:title], comment_params[:body], comment_params[:commentable_id]]
    end
  end

  def handle_comment_for_non_logged_in_user
    if session[:title] && session[:body] && session[:news_item_id]
      self.current_user.comments.create(:commentable_id => session[:news_item_id], :commentable_type => "NewsItem", :title => session[:title], :body => session[:body])
      session[:news_item_id] = nil
      session[:title] = nil
      session[:body] = nil
    end
  end

  layout :application_except_xhr
  def application_except_xhr
    request.xhr? ? false : "application"
  end

  def set_ajax_flash(type, message)
    if request.xhr?
      headers["X-Flash-#{type.to_s.capitalize}"] = message
    else
      flash[type] = message
    end
  end

  def flash_and_redirect(type, message, url = root_path)
    set_ajax_flash(type, message)
    if request.xhr?
      render :nothing => true
    else
      redirect_to url
    end
  end
end
