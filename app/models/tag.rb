class Tag < ApplicationRecord
  has_many :user_tags, dependent: :destroy
  has_many :users, through: :user_tags

  before_validation :strip_name

  validates :name,
            presence: true,
            length: { maximum: 100 },
            format: { without: /[\r\n]/, message: "cannot contain newlines" },
            uniqueness: { case_sensitive: false }

  scope :matching, ->(q) {
    query = q.to_s.strip
    return none if query.empty?

    where("LOWER(name) LIKE ?", "%#{sanitize_sql_like(query.downcase)}%")
      .order(:name)
      .limit(10)
  }

  def self.find_or_create_by_name!(raw_name)
    name = raw_name.to_s.strip
    existing = where("LOWER(name) = ?", name.downcase).first
    return existing if existing

    create!(name: name)
  rescue ActiveRecord::RecordNotUnique
    where("LOWER(name) = ?", name.downcase).first!
  end

  private

  def strip_name
    self.name = name.strip if name.is_a?(String)
  end
end
