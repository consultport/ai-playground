require "test_helper"

class Admin::TagsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @admin = users(:admin_user)
    @regular_user = users(:confirmed_user)
  end

  # --- Authorization ---

  test "unauthenticated user is redirected to sign-in" do
    get admin_tags_path, params: { q: "fi" }
    assert_redirected_to new_user_session_path
  end

  test "non-admin user is redirected to dashboard" do
    sign_in @regular_user
    get admin_tags_path, params: { q: "fi" }
    assert_redirected_to dashboard_path
    assert_equal "You are not authorized to access this page.", flash[:alert]
  end

  # --- #index ---

  test "returns JSON array with { id, text } shape only" do
    sign_in @admin
    get admin_tags_path, params: { q: "finance" }

    assert_response :success
    assert_equal "application/json", response.media_type

    body = JSON.parse(response.body)
    assert_kind_of Array, body
    assert_equal 1, body.size
    row = body.first
    assert_equal %w[id text].sort, row.keys.sort
    assert_equal tags(:finance).id, row["id"]
    assert_equal tags(:finance).name, row["text"]
  end

  test "substring match is case-insensitive" do
    sign_in @admin
    get admin_tags_path, params: { q: "FiN" }

    body = JSON.parse(response.body)
    names = body.map { |row| row["text"] }
    assert_includes names, "Finance"
  end

  test "substring match works on internal substrings (not only prefix)" do
    sign_in @admin
    get admin_tags_path, params: { q: "esi" } # matches "Design"

    body = JSON.parse(response.body)
    names = body.map { |row| row["text"] }
    assert_includes names, "Design"
  end

  test "results are returned in alphabetical order" do
    sign_in @admin
    # All fixture tags contain the letter "e" except ... let's use a distinctive shared substring.
    # "sort-z", "sort-a", "sort-m" -> expect a, m, z
    Tag.create!(name: "sort-zed")
    Tag.create!(name: "sort-alpha")
    Tag.create!(name: "sort-mid")

    get admin_tags_path, params: { q: "sort-" }

    names = JSON.parse(response.body).map { |row| row["text"] }
    assert_equal names.sort, names
  end

  test "results are capped at 10" do
    sign_in @admin
    11.times { |i| Tag.create!(name: "limitcheck-#{i.to_s.rjust(2, '0')}") }

    get admin_tags_path, params: { q: "limitcheck" }

    body = JSON.parse(response.body)
    assert_equal 10, body.size
  end

  test "returns [] when q is blank" do
    sign_in @admin

    ["", "   "].each do |q|
      get admin_tags_path, params: { q: q }
      body = JSON.parse(response.body)
      assert_equal [], body, "Expected empty array for q=#{q.inspect}"
    end
  end

  test "returns [] when q param is missing" do
    sign_in @admin

    get admin_tags_path

    body = JSON.parse(response.body)
    assert_equal [], body
  end
end
