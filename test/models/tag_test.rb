require "test_helper"

class TagTest < ActiveSupport::TestCase
  # Presence

  test "valid tag passes validation" do
    tag = Tag.new(name: "Marketing")
    assert tag.valid?
  end

  test "name must be present" do
    [nil, "", "   "].each do |blank_name|
      tag = Tag.new(name: blank_name)
      assert_not tag.valid?, "Expected tag with blank name #{blank_name.inspect} to be invalid"
      assert_includes tag.errors[:name], "can't be blank"
    end
  end

  # Length

  test "name cannot exceed 100 characters" do
    tag = Tag.new(name: "a" * 101)
    assert_not tag.valid?
    assert_includes tag.errors[:name], "is too long (maximum is 100 characters)"
  end

  test "name with exactly 100 characters is valid" do
    tag = Tag.new(name: "a" * 100)
    assert tag.valid?
  end

  # Newlines

  test "name cannot contain a line-feed character" do
    tag = Tag.new(name: "foo\nbar")
    assert_not tag.valid?
    assert_includes tag.errors[:name], "cannot contain newlines"
  end

  test "name cannot contain a carriage-return character" do
    tag = Tag.new(name: "foo\rbar")
    assert_not tag.valid?
    assert_includes tag.errors[:name], "cannot contain newlines"
  end

  # Trim

  test "leading and trailing whitespace is stripped before validation" do
    tag = Tag.new(name: "  Marketing  ")
    assert tag.valid?
    assert_equal "Marketing", tag.name
  end

  test "a whitespace-only name is treated as blank after strip" do
    tag = Tag.new(name: "   ")
    assert_not tag.valid?
    assert_includes tag.errors[:name], "can't be blank"
  end

  # Uniqueness (case-insensitive)

  test "name uniqueness is case-insensitive" do
    tag = Tag.new(name: tags(:finance).name.upcase)
    assert_not tag.valid?
    assert_includes tag.errors[:name], "has already been taken"
  end

  test "name uniqueness is case-insensitive for mixed case" do
    tag = Tag.new(name: "fInAnCe")
    assert_not tag.valid?
    assert_includes tag.errors[:name], "has already been taken"
  end

  # .matching scope

  test ".matching returns none for blank queries" do
    [nil, "", "   "].each do |q|
      assert_equal [], Tag.matching(q).to_a, "Expected empty result for q=#{q.inspect}"
    end
  end

  test ".matching returns substring matches" do
    names = Tag.matching("nance").pluck(:name)
    assert_includes names, "Finance"
  end

  test ".matching is case-insensitive" do
    assert_includes Tag.matching("FINANCE").pluck(:name), "Finance"
    assert_includes Tag.matching("finance").pluck(:name), "Finance"
    assert_includes Tag.matching("FiNaNcE").pluck(:name), "Finance"
  end

  test ".matching returns results in alphabetical order" do
    # Create extra tags to have something to sort meaningfully.
    Tag.create!(name: "alpha-item")
    Tag.create!(name: "zeta-item")
    Tag.create!(name: "Mid-item")

    names = Tag.matching("item").pluck(:name)
    assert_equal names.sort, names
  end

  test ".matching caps results at 10" do
    11.times { |i| Tag.create!(name: "limitcheck-#{i.to_s.rjust(2, '0')}") }

    assert_equal 10, Tag.matching("limitcheck").count
  end

  # .find_or_create_by_name!

  test ".find_or_create_by_name! creates a new tag when it doesn't exist" do
    assert_difference("Tag.count", 1) do
      tag = Tag.find_or_create_by_name!("Brand New")
      assert_equal "Brand New", tag.name
    end
  end

  test ".find_or_create_by_name! trims whitespace before creating" do
    tag = Tag.find_or_create_by_name!("  Trimmed  ")
    assert_equal "Trimmed", tag.name
  end

  test ".find_or_create_by_name! returns the existing canonical row (case-insensitive lookup)" do
    canonical = tags(:finance)

    assert_no_difference("Tag.count") do
      result = Tag.find_or_create_by_name!(canonical.name.upcase)
      assert_equal canonical.id, result.id
      # Preserves original casing, not the casing of the input.
      assert_equal canonical.name, result.name
    end
  end

  test ".find_or_create_by_name! is a no-op when the tag already exists with the exact casing" do
    canonical = tags(:finance)

    assert_no_difference("Tag.count") do
      result = Tag.find_or_create_by_name!(canonical.name)
      assert_equal canonical.id, result.id
    end
  end

  test ".find_or_create_by_name! treats leading/trailing whitespace as equivalent for lookup" do
    canonical = tags(:finance)

    assert_no_difference("Tag.count") do
      result = Tag.find_or_create_by_name!("  #{canonical.name}  ")
      assert_equal canonical.id, result.id
    end
  end
end
