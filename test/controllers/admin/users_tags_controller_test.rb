require "test_helper"

class Admin::Users::TagsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @admin = users(:admin_user)
    @regular_user = users(:confirmed_user)
    @existing_tag = tags(:finance)
    @other_tag = tags(:operations)
    # @admin has :finance already applied via the user_tags fixture.
  end

  # --- Authorization ---

  test "#create redirects unauthenticated requests to sign-in" do
    assert_no_difference("Tag.count") do
      assert_no_difference("UserTag.count") do
        post admin_user_tags_path(@regular_user),
             params: { tag: { name: "Something" } },
             as: :turbo_stream
      end
    end
    assert_redirected_to new_user_session_path
  end

  test "#destroy redirects unauthenticated requests to sign-in" do
    user_tag = UserTag.create!(user: @regular_user, tag: @existing_tag)

    assert_no_difference("UserTag.count") do
      delete admin_user_tag_path(@regular_user, @existing_tag),
             as: :turbo_stream
    end
    assert_redirected_to new_user_session_path

    user_tag.destroy
  end

  # --- #create ---

  test "#create creates a new tag and join when the tag doesn't exist" do
    sign_in @admin

    assert_difference("Tag.count", 1) do
      assert_difference("UserTag.count", 1) do
        post admin_user_tags_path(@regular_user),
             params: { tag: { name: "Brand New Tag" } },
             as: :turbo_stream
      end
    end

    assert_response :success
    tag = Tag.find_by!("LOWER(name) = ?", "brand new tag")
    assert_equal "Brand New Tag", tag.name
    assert @regular_user.reload.tags.include?(tag)
  end

  test "#create reuses an existing tag (case-insensitive) without duplicating the Tag row" do
    sign_in @admin

    assert_no_difference("Tag.count") do
      assert_difference("UserTag.count", 1) do
        post admin_user_tags_path(@regular_user),
             params: { tag: { name: @existing_tag.name.upcase } },
             as: :turbo_stream
      end
    end

    assert_response :success
    assert @regular_user.reload.tags.include?(@existing_tag)
  end

  test "#create trims whitespace and reuses the canonical tag" do
    sign_in @admin

    assert_no_difference("Tag.count") do
      assert_difference("UserTag.count", 1) do
        post admin_user_tags_path(@regular_user),
             params: { tag: { name: "  #{@existing_tag.name}  " } },
             as: :turbo_stream
      end
    end

    assert_response :success
    assert @regular_user.reload.tags.include?(@existing_tag)
  end

  test "#create is idempotent when the join already exists (no duplicate UserTag row)" do
    sign_in @admin

    # @admin already has :finance applied via the fixture.
    assert_no_difference("Tag.count") do
      assert_no_difference("UserTag.count") do
        post admin_user_tags_path(@admin),
             params: { tag: { name: @existing_tag.name } },
             as: :turbo_stream
      end
    end

    assert_response :success
  end

  test "#create is idempotent even with case-insensitive name for an already-applied tag" do
    sign_in @admin

    assert_no_difference("Tag.count") do
      assert_no_difference("UserTag.count") do
        post admin_user_tags_path(@admin),
             params: { tag: { name: @existing_tag.name.swapcase } },
             as: :turbo_stream
      end
    end

    assert_response :success
  end

  test "#create returns 422 turbo-stream when the name is blank" do
    sign_in @admin

    assert_no_difference("Tag.count") do
      assert_no_difference("UserTag.count") do
        post admin_user_tags_path(@regular_user),
             params: { tag: { name: "" } },
             as: :turbo_stream
      end
    end

    assert_response :unprocessable_entity
    assert_equal Mime[:turbo_stream], response.media_type
  end

  test "#create returns 422 turbo-stream when the name is whitespace-only" do
    sign_in @admin

    assert_no_difference("Tag.count") do
      assert_no_difference("UserTag.count") do
        post admin_user_tags_path(@regular_user),
             params: { tag: { name: "   " } },
             as: :turbo_stream
      end
    end

    assert_response :unprocessable_entity
    assert_equal Mime[:turbo_stream], response.media_type
  end

  test "#create returns 422 turbo-stream when the name contains a newline" do
    sign_in @admin

    assert_no_difference("Tag.count") do
      post admin_user_tags_path(@regular_user),
           params: { tag: { name: "foo\nbar" } },
           as: :turbo_stream
    end

    assert_response :unprocessable_entity
    assert_equal Mime[:turbo_stream], response.media_type
  end

  test "#create responds with a turbo_stream that replaces the #user-tags frame" do
    sign_in @admin

    post admin_user_tags_path(@regular_user),
         params: { tag: { name: "StreamCheck" } },
         as: :turbo_stream

    assert_response :success
    assert_equal Mime[:turbo_stream], response.media_type
    assert_match(/turbo-stream[^>]+action="replace"[^>]+target="user-tags"/, response.body)
  end

  # --- #destroy ---

  test "#destroy removes the UserTag join but not the Tag itself" do
    sign_in @admin
    # Use the admin's existing fixture join (admin -> finance).
    assert UserTag.exists?(user: @admin, tag: @existing_tag), "Precondition: admin has :finance applied"

    assert_no_difference("Tag.count") do
      assert_difference("UserTag.count", -1) do
        delete admin_user_tag_path(@admin, @existing_tag),
               as: :turbo_stream
      end
    end

    assert_response :success
    assert_not @admin.reload.tags.include?(@existing_tag)
    assert Tag.exists?(@existing_tag.id), "Tag row itself must still exist"
  end

  test "#destroy is idempotent when no matching join exists" do
    sign_in @admin
    # @other_tag (operations) is not applied to @regular_user.
    assert_not UserTag.exists?(user: @regular_user, tag: @other_tag)

    assert_no_difference("UserTag.count") do
      delete admin_user_tag_path(@regular_user, @other_tag),
             as: :turbo_stream
    end

    assert_response :success
  end

  test "#destroy responds with a turbo_stream that replaces the #user-tags frame" do
    sign_in @admin

    delete admin_user_tag_path(@admin, @existing_tag),
           as: :turbo_stream

    assert_response :success
    assert_equal Mime[:turbo_stream], response.media_type
    assert_match(/turbo-stream[^>]+action="replace"[^>]+target="user-tags"/, response.body)
  end
end
