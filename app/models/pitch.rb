# == Schema Information
# Schema version: 20090218144012
#
# Table name: news_items
#
#  id                          :integer(4)      not null, primary key
#  headline                    :string(255)
#  location                    :string(255)
#  state                       :string(255)
#  short_description           :text
#  delivery_description        :text
#  extended_description        :text
#  skills                      :text
#  keywords                    :string(255)
#  deliver_text                :boolean(1)      not null
#  deliver_audio               :boolean(1)      not null
#  deliver_video               :boolean(1)      not null
#  deliver_photo               :boolean(1)      not null
#  contract_agreement          :boolean(1)      not null
#  expiration_date             :datetime
#  created_at                  :datetime
#  updated_at                  :datetime
#  featured_image_file_name    :string(255)
#  featured_image_content_type :string(255)
#  featured_image_file_size    :integer(4)
#  featured_image_updated_at   :datetime
#  type                        :string(255)
#  video_embed                 :text
#  featured_image_caption      :string(255)
#  user_id                     :integer(4)
#  status                      :string(255)
#  feature                     :boolean(1)
#  fact_checker_id             :integer(4)
#  news_item_id                :integer(4)
#  deleted_at                  :datetime
#  widget_embed                :text
#  requested_amount            :decimal(15, 2)
#  current_funding             :decimal(15, 2)
#

class Pitch < NewsItem
  aasm_initial_state  :unapproved

  aasm_state :unapproved
  aasm_state :active
  aasm_state :accepted
  aasm_state :funded

  aasm_event :unapprove do
    transitions :from => :active, :to => :unapproved
  end

  aasm_event :approve do
    transitions :from => :unapproved, :to => :active, :on_transition => :send_approved_notification
  end

  aasm_event :fund do
    transitions :from => [:unapproved, :active], :to => :funded, :on_transition => :do_fund_events
  end

  aasm_event :accept do
    transitions :from => [:unapproved, :active], :to => :accepted, :on_transition => :do_fund_events
  end

  validates_presence_of :requested_amount
  validates_presence_of :short_description
  validates_presence_of :extended_description
  validates_presence_of :delivery_description
  validates_presence_of :skills
  validates_presence_of :featured_image_caption

  if Rails.env.production?
    validates_presence_of :featured_image_file_name
  end

  # Next :accept required because of rails bug:
  # http://skwpspace.com/2008/02/21/validates_acceptance_of-behavior-in-rails-20/
  validates_acceptance_of :contract_agreement, :accept => true, :allow_nil => false

  has_many :affiliations, :dependent => :destroy
  has_many :tips, :through => :affiliations
  has_many :organization_pitches, :foreign_key => :pitch_id
  has_many :supporting_organizations, :through => :organization_pitches, :source => :organization
  has_many :donations, :dependent => :destroy do
    def for_user(user)
      find_all_by_user_id(user.id)
    end

    def total_amount_for_user(user)
      for_user(user).map(&:amount).sum
    end
  end
  has_many :supporters, :through => :donations, :source => :user, :order => "donations.created_at", :uniq => true
  has_many :posts do
    def first(number)
      find(:all, :limit => number, :order => 'created_at DESC')
    end
  end
  has_many :contributor_applications do
    def unapproved
      find_all_by_approved(false)
    end
  end
  has_many :contributors, :through => :contributor_applications, :source => :user, :conditions => ['contributor_applications.approved = ?', true]
  has_many :contributor_applicants, :through => :contributor_applications, :source => :user

  has_one :story, :foreign_key => 'news_item_id', :dependent => :destroy

  belongs_to :fact_checker, :class_name => 'User', :foreign_key => 'fact_checker_id'

  after_create :send_admin_notification
  after_save :check_if_funded_state, :dispatch_fact_checker

  named_scope :most_funded, :order => 'news_items.current_funding DESC'
  named_scope :featured, :conditions => {:feature => true}, :order => 'RAND()'
  named_scope :almost_funded, :select => "news_items.*, case when news_items.status = 'active' then (1.0 - (news_items.current_funding / news_items.requested_amount)) else news_items.created_at end as sort_value", :order => "sort_value ASC"
  named_scope :sorted, lambda {|direction| { :order => "news_items.created_at #{direction}" } }
  named_scope :without_a_story, :conditions => 'news_items.id NOT IN (SELECT news_item_id FROM news_items WHERE news_items.type = "Story" AND news_items.status = "published")'
  named_scope :browsable, :include => :user, :conditions => "news_items.status != 'unapproved'"

  MAX_PER_USER_DONATION_PERCENTAGE = 0.20

  def self.featured_by_network(network=nil)
    return network.featured_pitches if network
    Network.with_pitches.map do |network|
      network.featured_pitches
    end.flatten
  end

  def can_be_accepted?
    active?
  end

  def editable_by?(user)
    if user.nil?
      false
    else
      ((self.user == user) && (donations.paid.blank? && (unapproved? || active?))) || user.admin?
    end
  end

  def postable_by?(other_user)
    return false if other_user.nil?
    user == other_user || other_user.admin? || other_user == fact_checker || contributors.include?(other_user)
  end

  def approvable_by?(current_user)
    return false if current_user.nil?
    current_user.admin? && (active? || unapproved?)
  end

  def current_funding
    return total_amount_donated if accepted?
    return requested_amount if self[:current_funding] && self[:current_funding] > requested_amount
    self[:current_funding] || 0
  end

  def current_funding_in_percentage
    (current_funding/requested_amount)
  end

  def check_if_funded_state
    if fully_funded? && active?
      fund!
    end
  end

  def self.with_sort(sort='desc')
    self.browsable.without_a_story.send(sanitize_sort(sort))
  end

  def self.createable_by?(user)
    user && user.reporter?
  end

  def featured?
    self.feature
  end

  def show_support!(organization)
    supporting_organizations << organization unless supporting_organizations.include?(organization)
  end

  def apply_to_contribute(user)
    return false unless user
    unless contributors.include?(user)
      contributors << user
      Mailer.deliver_admin_reporting_team_notification(self)
      Mailer.deliver_reporter_reporting_team_notification(self)
      Mailer.deliver_applied_reporting_team_notification(self, user)
    end
  end

  def feature!
    self.update_attribute(:feature, true)
  end

  def unfeature!
    self.update_attribute(:feature, false)
  end

  def featureable_by?(user)
    user.is_a?(Admin)
  end

  def approve_blogger!(user_id)
    return if user_id.nil?
    return unless application = contributor_applications.detect{|ca| ca.user_id == user_id.to_i}
    application.update_attribute(:approved, true)
    Mailer.deliver_approved_reporting_team_notification(self, application.user)
  end

  def unapprove_blogger!(user_id)
    return if user_id.nil?
    return unless application = contributor_applications.detect{|ca| ca.user_id == user_id.to_i}
    application.update_attribute(:approved, false)
  end

  def funding_needed
    return 0 unless active? || unapproved?
    requested_amount - total_amount_donated
  end

  def half_funded?
    return true if accepted? || funded?
    total_amount_donated > (requested_amount / 2)
  end

  def half_fund!(user)
    donations.unpaid.for_user(user).map(&:destroy)
    donations.create(:amount => requested_amount / 2, :user => user)
  end

  def fully_funded?
    return true if accepted? || funded?
    total_amount_donated >= requested_amount
  end

  def fully_fund!(user)
    donations.unpaid.for_user(user).map(&:destroy)
    donations.create(:amount => requested_amount, :user => user)
  end

  def requested_amount=(value)
    self[:requested_amount] = value.to_s.gsub(/[^\d\.]/, "") unless value.nil?
  end

  def total_amount_donated
    donations.paid.map(&:amount).sum
  end

  def donated_to?
    donations.paid.any?
  end

  def donation_limit_per_user
    requested_amount * MAX_PER_USER_DONATION_PERCENTAGE
  end

  def max_donation_amount(user)
    if user.organization? || (funding_needed < donation_limit_per_user)
      funding_needed
    else
      donation_limit_per_user
    end
  end

  def default_donation_amount
    [Donation::DEFAULT_AMOUNT, donation_limit_per_user, funding_needed].min
  end

  def user_can_donate_more?(user, attempted_donation_amount)
    return false if attempted_donation_amount.nil?
    return true if user.organization? && attempted_donation_amount <= requested_amount
    return false if attempted_donation_amount > funding_needed
    user_donations = donations.paid.total_amount_for_user(user)
    (user_donations + attempted_donation_amount) <= max_donation_amount(user)
  end

  def dispatch_fact_checker
    if self.fact_checker_id_changed? && self.story
      self.story.update_attribute(:fact_checker_id, self.fact_checker_id)
    end
  end

  def has_more_posts_than(number)
    posts.size > number
  end

  def donating_groups
    Donation.paid.for_pitch(self).map(&:group).uniq.compact
  end

  protected

  def do_fund_events
    send_fund_notification
    create_associated_story
  end

  def create_associated_story
    self.create_story(:headline => self.headline, :network => self.network, :category => self.category, :user => self.user)
  end

  def send_fund_notification
    Mailer.deliver_pitch_accepted_notification(self)
  end

  def send_admin_notification
    Mailer.deliver_pitch_created_notification(self)
  end

  def send_approved_notification
    Mailer.deliver_pitch_approved_notification(self)
  end
end

