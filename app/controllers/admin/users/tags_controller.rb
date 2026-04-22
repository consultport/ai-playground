class Admin::Users::TagsController < Admin::BaseController
  before_action :set_user

  def create
    tag = Tag.find_or_create_by_name!(tag_params[:name])
    @user.user_tags.find_or_create_by!(tag: tag)

    respond_to do |format|
      format.turbo_stream
    end
  rescue ActiveRecord::RecordInvalid => e
    @error_message = e.record.errors.full_messages.to_sentence.presence || "Tag is invalid"
    respond_to do |format|
      format.turbo_stream { render :create, status: :unprocessable_entity }
    end
  end

  def destroy
    @user.user_tags.find_by(tag_id: params[:id])&.destroy

    respond_to do |format|
      format.turbo_stream
    end
  end

  private

  def set_user
    @user = User.find(params[:user_id])
  end

  def tag_params
    params.require(:tag).permit(:name)
  end
end
