class Mailer < ActionMailer::Base
  include ActionController::UrlWriter
  default_url_options[:host] = DEFAULT_HOST

  def activation_email(user)
    recipients user.email
    from       MAIL_FROM_INFO
    subject    %(Welcome to CSJ Northfield – Please verify your email address")
    body :user => user
  end

  def citizen_signup_notification(user)
    recipients user.email
    from       MAIL_FROM_INFO
    subject    %(Welcome to CSJ Northfield – "Community Supported Journalism")
    body :user => user
  end

  def reporter_signup_notification(user)
    recipients user.email
    from       MAIL_FROM_INFO
    subject    "Welcome to CSJ Northfield – Reporting on Communities"
    body :user => user
  end

  def organization_signup_notification(user)
    recipients user.email
    from       MAIL_FROM_INFO
    subject    "CSJ Northfield: Important Information on Joining"
    body :user => user
  end

  def news_org_signup_request(user)
    recipients '"David Cohn" <csjnorthfield@gmail.com>'
    from       MAIL_FROM_INFO
    subject    "CSJ Northfield: News Org Requesting to Join"
    body        :user => user
  end

  def password_reset_notification(user)
    recipients user.email
    from       MAIL_FROM_INFO
    subject    "CSJ Northfield: Password Reset"
    body       :user => user
  end

  def pitch_created_notification(pitch)
    recipients '"David Cohn" <csjnorthfield@gmail.com>'
    from       MAIL_FROM_INFO
    subject    "CSJ Northfield: A pitch needs approval!"
    body       :pitch => pitch
  end

  def pitch_approved_notification(pitch)
    recipients pitch.user.email
    from       MAIL_FROM_INFO
    subject    "CSJ Northfield: Your pitch has been approved!"
    body       :pitch => pitch
  end

  def pitch_accepted_notification(pitch)
    recipients '"David Cohn" <csjnorthfield@gmail.com>'
    bcc pitch.supporters.map(&:email).concat(Admin.all.map(&:email)).join(', ')
    from       MAIL_FROM_INFO
    subject    "CSJ Northfield: Success!! Your Story is Funded!"
    body       :pitch => pitch
  end

  def admin_reporting_team_notification(pitch)
    recipients '"David Cohn" <csjnorthfield@gmail.com>'
    from       MAIL_FROM_INFO
    subject    "CSJ Northfield: Someone wants to join a pitch's reporting team!"
    body       :pitch => pitch
  end

  def reporter_reporting_team_notification(pitch)
    recipients pitch.user.email
    from       MAIL_FROM_INFO
    subject    "CSJ Northfield: Someone wants to join your reporting team!"
    body       :pitch => pitch
  end

  def approved_reporting_team_notification(pitch, user)
    recipients user.email
    from       MAIL_FROM_INFO
    subject    "CSJ Northfield: Welcome to the reporting team!"
    body       :pitch => pitch
  end

  def applied_reporting_team_notification(pitch, user)
    recipients user.email
    from       MAIL_FROM_INFO
    subject    "CSJ Northfield: We received your application!"
    body       :pitch => pitch
  end

  def story_ready_notification(story)
    recipients '"David Cohn" <csjnorthfield@gmail.com>'
    from       MAIL_FROM_INFO
    subject    "CSJ Northfield: Story ready for publishing"
    body       :story => story
  end

  def organization_approved_notification(user)
    recipients user.email
    from       MAIL_FROM_INFO
    subject    "CSJ Northfield: Important Information on Joining"
    body       :user => user
  end

  def user_thank_you_for_donating(donation)
    recipients  donation.user.email
    from        MAIL_FROM_INFO
    subject     "CSJ Northfield: Thank You for Donating!"
    body        :donation => donation
  end
end
