require "application_system_test_case"

class AdminUserTagsTest < ApplicationSystemTestCase
  setup do
    @admin = users(:admin_user)
    @regular_user = users(:confirmed_user)
    @finance = tags(:finance)
    @operations = tags(:operations)
    @strategy = tags(:strategy)
    @design = tags(:design)
  end

  # --- Empty state ---

  test "empty state renders the 'Add a tag…' placeholder on a user with no tags" do
    sign_in_as(@admin)
    visit admin_user_path(@regular_user)

    assert_text "Internal tags"
    assert_selector "input[placeholder='Add a tag…']"
    assert_no_selector "[data-tag-input-target='pill']"
  end

  # --- Dropdown opens on partial match and picking a row adds a pill ---

  test "typing a partial match opens the dropdown, and picking a row adds a green pill" do
    sign_in_as(@admin)
    visit admin_user_path(@regular_user)

    input = find("input[data-tag-input-target='input']")
    input.click
    input.fill_in(with: "Fin")

    # Dropdown opens and shows the matching row.
    within "[data-tag-input-target='dropdown']" do
      assert_selector "li", text: @finance.name
    end

    # Click the row to pick it.
    find("[data-tag-input-target='dropdown'] li", text: @finance.name).click

    # Wait for the turbo-stream reply to re-render the frame with a pill.
    within "turbo-frame#user-tags" do
      assert_selector "[data-tag-input-target='pill']", text: @finance.name
    end

    # Pill has the branded green background class.
    assert_selector "span.bg-\\[\\#3f9c43\\]", text: @finance.name

    # Persisted on the server.
    assert @regular_user.reload.tags.include?(@finance)

    # Dropdown closed after the pick.
    assert_selector "[data-tag-input-target='dropdown'].hidden", visible: :all
  end

  # --- Creating a brand-new tag via Enter ---

  test "typing a brand-new name and pressing Enter creates the tag and shows it as a pill" do
    sign_in_as(@admin)
    visit admin_user_path(@regular_user)

    input = find("input[data-tag-input-target='input']")
    input.click
    input.fill_in(with: "Marketing")

    input.send_keys(:enter)

    within "turbo-frame#user-tags" do
      assert_selector "[data-tag-input-target='pill']", text: "Marketing"
    end

    # New Tag row was created and joined.
    new_tag = Tag.find_by!("LOWER(name) = ?", "marketing")
    assert_equal "Marketing", new_tag.name
    assert @regular_user.reload.tags.include?(new_tag)

    # Input was cleared.
    assert_equal "", find("input[data-tag-input-target='input']").value
  end

  # --- Removing a pill ---

  test "clicking the × on a pill removes it (no confirm dialog)" do
    # Give the regular user a pre-applied tag to remove.
    UserTag.create!(user: @regular_user, tag: @finance)

    sign_in_as(@admin)
    visit admin_user_path(@regular_user)

    within "turbo-frame#user-tags" do
      assert_selector "[data-tag-input-target='pill']", text: @finance.name
    end

    find("button[aria-label='Remove #{@finance.name}']").click

    within "turbo-frame#user-tags" do
      assert_no_selector "[data-tag-input-target='pill']", text: @finance.name
    end

    assert_not @regular_user.reload.tags.include?(@finance)
  end

  # --- Already-applied tags appear disabled in the dropdown ---

  test "an already-applied tag appears in the dropdown as aria-disabled and is not clickable" do
    UserTag.create!(user: @regular_user, tag: @finance)

    sign_in_as(@admin)
    visit admin_user_path(@regular_user)

    input = find("input[data-tag-input-target='input']")
    input.click
    input.fill_in(with: "Fin")

    within "[data-tag-input-target='dropdown']" do
      assert_selector "li[aria-disabled='true']", text: @finance.name
    end

    # Clicking the disabled row must NOT create another UserTag row.
    assert_no_difference("UserTag.where(user: @regular_user).count") do
      find("[data-tag-input-target='dropdown'] li[aria-disabled='true']", text: @finance.name).click
      # Give any in-flight request a moment to settle.
      assert_selector "[data-tag-input-target='pill']", text: @finance.name, count: 1
    end
  end
end
