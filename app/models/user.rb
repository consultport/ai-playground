class User < ApplicationRecord
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable, :confirmable

  enum :role, { user: 0, admin: 1 }, default: :user

  has_one_attached :avatar

  has_many :user_tags, dependent: :destroy
  has_many :tags, through: :user_tags

  validates :name, presence: true, length: { maximum: 100 }
  validates :nickname, length: { maximum: 50 }, allow_blank: true
  validate :must_have_at_least_one_admin, if: -> { role_changed? && role_was == "admin" }

  after_create_commit :broadcast_to_admins
  after_update_commit :broadcast_dashboard_refresh, if: :saved_change_to_confirmed_at?

  private

  def broadcast_to_admins
    broadcast_append_to("admin_notifications",
      target: "admin_toast_container",
      partial: "admin/shared/new_user_toast",
      locals: { user: self })

    broadcast_prepend_to("admin_notifications",
      target: "admin_users_table_body",
      partial: "admin/users/user_row",
      locals: { user: self, current_user: nil })

    broadcast_dashboard_refresh
  end

  def broadcast_dashboard_refresh
    Turbo::StreamsChannel.broadcast_action_to(
      "admin_dashboard_stats",
      action: "reload_frame",
      target: "dashboard_stats"
    )
  end

  def must_have_at_least_one_admin
    if User.where(role: :admin).where.not(id: id).count.zero?
      errors.add(:role, "cannot be changed. At least one admin must exist.")
    end
  end
end
