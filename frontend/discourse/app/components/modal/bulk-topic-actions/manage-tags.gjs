import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn, hash } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { trustHTML } from "@ember/template";
import DButton from "discourse/components/d-button";
import DToggleSwitch from "discourse/components/d-toggle-switch";
import concatClass from "discourse/helpers/concat-class";
import TagChooser from "discourse/select-kit/components/tag-chooser";
import { i18n } from "discourse-i18n";

export default class ManageTags extends Component {
  @tracked addTags = [];
  @tracked removeTags = [];
  @tracked removeAllTags = false;
  @tracked replaceRows = [{ from: [], to: [] }];

  constructor() {
    super(...arguments);
    this.args.onRegister?.(this);
  }

  get isValid() {
    const hasPartialReplace = this.replaceRows.some(
      (r) => r.from.length > 0 !== r.to.length > 0
    );
    const hasAny =
      this.removeAllTags ||
      this.addTags.length ||
      this.removeTags.length ||
      this.replaceRows.some((r) => r.from.length && r.to.length);
    return hasAny && !hasPartialReplace;
  }

  buildOperation() {
    if (this.removeAllTags) {
      return {
        type: "manage_tags",
        add_tag_ids: [],
        remove_tag_ids: [],
        remove_all_tags: true,
        replace: [],
      };
    }

    return {
      type: "manage_tags",
      add_tag_ids: this.addTags.map((t) => t.id),
      remove_tag_ids: this.removeTags.map((t) => t.id),
      remove_all_tags: false,
      replace: this.replaceRows
        .filter((r) => r.from.length && r.to.length)
        .map((r) => ({
          from_tag_id: r.from[0].id,
          to_tag_id: r.to[0].id,
        })),
    };
  }

  get replaceFromTags() {
    return this.replaceRows.flatMap((r) => r.from);
  }

  get replaceToTags() {
    return this.replaceRows.flatMap((r) => r.to);
  }

  get addBlockedTags() {
    return [...this.removeTags, ...this.replaceFromTags, ...this.replaceToTags];
  }

  get removeBlockedTags() {
    return [...this.addTags, ...this.replaceFromTags, ...this.replaceToTags];
  }

  @action
  replaceBlockedTagsFor(index, field) {
    const otherReplaceTags = this.replaceRows.flatMap((r, i) =>
      i === index ? r[field === "from" ? "to" : "from"] : [...r.from, ...r.to]
    );
    return [...this.addTags, ...this.removeTags, ...otherReplaceTags];
  }

  @action
  showMissingFromFor(index) {
    const row = this.replaceRows[index];
    return row && row.to.length > 0 && row.from.length === 0;
  }

  @action
  showMissingToFor(index) {
    const row = this.replaceRows[index];
    return row && row.from.length > 0 && row.to.length === 0;
  }

  @action
  onAddTagsChange(tags) {
    this.addTags = tags;
  }

  @action
  onRemoveTagsChange(tags) {
    this.removeTags = tags;
  }

  @action
  toggleRemoveAllTags() {
    this.removeAllTags = !this.removeAllTags;
  }

  @action
  onReplaceFromChange(index, tags) {
    const last = tags.slice(-1);
    this.replaceRows = this.replaceRows.map((r, i) =>
      i === index ? { from: last, to: r.to } : r
    );
  }

  @action
  onReplaceToChange(index, tags) {
    const last = tags.slice(-1);
    this.replaceRows = this.replaceRows.map((r, i) =>
      i === index ? { from: r.from, to: last } : r
    );
  }

  @action
  addReplaceRow() {
    this.replaceRows = [...this.replaceRows, { from: [], to: [] }];
  }

  @action
  removeReplaceRow(index) {
    const rows = this.replaceRows.filter((_, i) => i !== index);
    this.replaceRows = rows.length ? rows : [{ from: [], to: [] }];
  }

  <template>
    <div class="manage-tags-form">
      <section
        class={{concatClass
          "manage-tags-section manage-tags-section--add"
          (if this.removeAllTags "is-disabled")
        }}
      >
        <label class="manage-tags-section__label">{{i18n
            "topic_bulk_actions.manage_tags.add.title"
          }}</label>
        <p class="manage-tags-section__description">
          {{i18n "topic_bulk_actions.manage_tags.add.description"}}
        </p>
        <TagChooser
          @tags={{this.addTags}}
          @onChange={{this.onAddTagsChange}}
          @blockedTags={{this.addBlockedTags}}
          @categoryId={{@categoryId}}
          @options={{hash disabled=this.removeAllTags}}
        />
      </section>

      <section class="manage-tags-section manage-tags-section--remove">
        <div class="manage-tags-section__header">
          <label class="manage-tags-section__label">
            {{i18n "topic_bulk_actions.manage_tags.remove.title"}}
          </label>
          <DToggleSwitch
            @state={{this.removeAllTags}}
            @translatedLabel={{i18n
              "topic_bulk_actions.manage_tags.remove.all_toggle"
            }}
            class="manage-tags-section__remove-all-toggle"
            {{on "click" this.toggleRemoveAllTags}}
          />
        </div>
        {{#if this.removeAllTags}}
          <div class="alert alert-error manage-tags-section__warning">
            {{trustHTML
              (i18n "topic_bulk_actions.manage_tags.remove.all_warning")
            }}
          </div>
        {{else}}
          <p class="manage-tags-section__description">
            {{i18n "topic_bulk_actions.manage_tags.remove.description"}}
          </p>
          <TagChooser
            @tags={{this.removeTags}}
            @onChange={{this.onRemoveTagsChange}}
            @blockedTags={{this.removeBlockedTags}}
            @categoryId={{@categoryId}}
          />
        {{/if}}
      </section>

      <section
        class={{concatClass
          "manage-tags-section manage-tags-section--replace"
          (if this.removeAllTags "is-disabled")
        }}
      >
        <label class="manage-tags-section__label">{{i18n
            "topic_bulk_actions.manage_tags.replace.title"
          }}</label>
        <p class="manage-tags-section__description">
          {{i18n "topic_bulk_actions.manage_tags.replace.description"}}
        </p>
        {{#each this.replaceRows key="@index" as |row index|}}
          <div class="manage-tags-replace-row">
            <div class="manage-tags-replace-row__field">
              <TagChooser
                @tags={{row.from}}
                @onChange={{fn this.onReplaceFromChange index}}
                @blockedTags={{this.replaceBlockedTagsFor index "from"}}
                @categoryId={{@categoryId}}
                @options={{hash
                  disabled=this.removeAllTags
                  maximum=1
                  filterPlaceholder="topic_bulk_actions.manage_tags.replace.from_placeholder"
                }}
                class={{concatClass
                  "manage-tags-replace-row__from"
                  (if (this.showMissingFromFor index) "has-error")
                }}
              />
              {{#if (this.showMissingFromFor index)}}
                <span class="manage-tags-replace-row__error">
                  {{i18n "topic_bulk_actions.manage_tags.replace.missing_from"}}
                </span>
              {{/if}}
            </div>
            <span
              class="manage-tags-replace-row__arrow"
              aria-hidden="true"
            >&rarr;</span>
            <div class="manage-tags-replace-row__field">
              <TagChooser
                @tags={{row.to}}
                @onChange={{fn this.onReplaceToChange index}}
                @blockedTags={{this.replaceBlockedTagsFor index "to"}}
                @categoryId={{@categoryId}}
                @options={{hash
                  disabled=this.removeAllTags
                  maximum=1
                  filterPlaceholder="topic_bulk_actions.manage_tags.replace.to_placeholder"
                }}
                class={{concatClass
                  "manage-tags-replace-row__to"
                  (if (this.showMissingToFor index) "has-error")
                }}
              />
              {{#if (this.showMissingToFor index)}}
                <span class="manage-tags-replace-row__error">
                  {{i18n "topic_bulk_actions.manage_tags.replace.missing_to"}}
                </span>
              {{/if}}
            </div>
            <DButton
              @icon="xmark"
              @action={{fn this.removeReplaceRow index}}
              @disabled={{this.removeAllTags}}
              @title="topic_bulk_actions.manage_tags.replace.remove_replacement"
              class="btn-transparent manage-tags-replace-row__remove"
            />
          </div>
        {{/each}}
        <DButton
          @icon="plus"
          @translatedLabel={{i18n
            "topic_bulk_actions.manage_tags.replace.add_replacement"
          }}
          @action={{this.addReplaceRow}}
          @disabled={{this.removeAllTags}}
          class="btn-default manage-tags-replace-row__add"
        />
      </section>
    </div>
  </template>
}
