class TipsController < ApplicationController
  resources_controller_for :tip, :except => :destroy

  before_filter :block_if_donated_to, :only => :edit

  bounce_bots(:send_bots, :tip, :blog_url)

  def block_if_donated_to
    t = find_resource(params[:id])
    if t.pledged_to? && !t.editable_by?(current_user)
      access_denied(:flash => "You cannot edit a tip that has pledges.  For minor changes, contact info@spot.us",
                    :redirect => tip_url(t))
    end
  end

  def index
    redirect_to news_items_path
  end

  private

  def send_bots
    self.resource = new_resource
    render :action => :new
  end

  def can_edit?
    access_denied unless find_resource.editable_by?(current_user)
  end

  def can_create?
    access_denied unless Tip.createable_by?(current_user)
  end

  def new_resource
    params[:tip] ||= {}
    params[:tip][:headline] = params[:headline] if params[:headline]
    current_user.tips.new(params[:tip])
  end
end
