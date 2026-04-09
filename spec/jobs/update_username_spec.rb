# frozen_string_literal: true

RSpec.describe Jobs::UpdateUsername do
  fab!(:user)

  it "does not do anything if user_id is invalid" do
    events =
      DiscourseEvent.track_events do
        described_class.new.execute(
          user_id: -999,
          old_username: user.username,
          new_username: "somenewusername",
          avatar_template: user.avatar_template,
        )
      end

    expect(events).to eq([])
  end

  it "updates the category description when a category description topic mentions the user" do
    category = Fabricate(:category_with_definition, user: Discourse.system_user)
    first_post = category.topic.first_post
    first_post.revise(first_post.user, { raw: "This category is managed by @#{user.username}" })
    category.reload

    expect(category.description).to include(user.username)

    old_username = user.username
    new_username = "new_username_123"

    described_class.new.execute(
      user_id: user.id,
      old_username:,
      new_username:,
      avatar_template: user.avatar_template,
    )
    category.reload

    expect(category.description).to include(new_username)
    expect(category.description).not_to include(old_username)
  end
end
