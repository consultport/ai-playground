require "test_helper"

class UserTagTest < ActiveSupport::TestCase
  setup do
    @user = users(:confirmed_user)
    @tag = tags(:operations)
  end

  # Associations

  test "belongs to a user" do
    association = UserTag.reflect_on_association(:user)
    assert_equal :belongs_to, association.macro
  end

  test "belongs to a tag" do
    association = UserTag.reflect_on_association(:tag)
    assert_equal :belongs_to, association.macro
  end

  test "requires a user" do
    user_tag = UserTag.new(tag: @tag)
    assert_not user_tag.valid?
    assert_includes user_tag.errors[:user], "must exist"
  end

  test "requires a tag" do
    user_tag = UserTag.new(user: @user)
    assert_not user_tag.valid?
    assert_includes user_tag.errors[:tag], "must exist"
  end

  # Composite uniqueness

  test "tag_id must be unique per user_id" do
    UserTag.create!(user: @user, tag: @tag)

    duplicate = UserTag.new(user: @user, tag: @tag)
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:tag_id], "has already been taken"
  end

  test "the same tag can be applied to different users" do
    UserTag.create!(user: @user, tag: @tag)

    other = UserTag.new(user: users(:second_confirmed_user), tag: @tag)
    assert other.valid?
  end

  test "the same user can have multiple distinct tags" do
    UserTag.create!(user: @user, tag: @tag)

    other = UserTag.new(user: @user, tag: tags(:strategy))
    assert other.valid?
  end
end
