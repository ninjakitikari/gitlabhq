<script>
import { mapGetters, mapState } from 'vuex';
import glFeatureFlagsMixin from '~/vue_shared/mixins/gl_feature_flags_mixin';
import draftCommentsMixin from '~/diffs/mixins/draft_comments';
import InlineDraftCommentRow from '~/batch_comments/components/inline_draft_comment_row.vue';
import inlineDiffTableRow from './inline_diff_table_row.vue';
import inlineDiffCommentRow from './inline_diff_comment_row.vue';
import inlineDiffExpansionRow from './inline_diff_expansion_row.vue';
import { getCommentedLines } from '~/notes/components/multiline_comment_utils';

export default {
  components: {
    inlineDiffCommentRow,
    inlineDiffTableRow,
    InlineDraftCommentRow,
    inlineDiffExpansionRow,
  },
  mixins: [draftCommentsMixin, glFeatureFlagsMixin()],
  props: {
    diffFile: {
      type: Object,
      required: true,
    },
    diffLines: {
      type: Array,
      required: true,
    },
    helpPagePath: {
      type: String,
      required: false,
      default: '',
    },
  },
  computed: {
    ...mapGetters('diffs', ['commitId']),
    ...mapState({
      selectedCommentPosition: ({ notes }) => notes.selectedCommentPosition,
      selectedCommentPositionHover: ({ notes }) => notes.selectedCommentPositionHover,
    }),
    diffLinesLength() {
      return this.diffLines.length;
    },
    commentedLines() {
      return getCommentedLines(
        this.selectedCommentPosition || this.selectedCommentPositionHover,
        this.diffLines,
      );
    },
  },
  userColorScheme: window.gon.user_color_scheme,
};
</script>

<template>
  <table
    :class="$options.userColorScheme"
    :data-commit-id="commitId"
    class="code diff-wrap-lines js-syntax-highlight text-file js-diff-inline-view"
  >
    <colgroup>
      <col style="width: 50px;" />
      <col style="width: 50px;" />
      <col style="width: 8px;" />
      <col />
    </colgroup>
    <tbody>
      <template v-for="(line, index) in diffLines">
        <inline-diff-expansion-row
          :key="`expand-${index}`"
          :file-hash="diffFile.file_hash"
          :context-lines-path="diffFile.context_lines_path"
          :line="line"
          :is-top="index === 0"
          :is-bottom="index + 1 === diffLinesLength"
        />
        <inline-diff-table-row
          :key="`${line.line_code || index}`"
          :file-hash="diffFile.file_hash"
          :file-path="diffFile.file_path"
          :line="line"
          :is-bottom="index + 1 === diffLinesLength"
          :is-commented="index >= commentedLines.startLine && index <= commentedLines.endLine"
        />
        <inline-diff-comment-row
          :key="`icr-${line.line_code || index}`"
          :diff-file-hash="diffFile.file_hash"
          :line="line"
          :help-page-path="helpPagePath"
          :has-draft="shouldRenderDraftRow(diffFile.file_hash, line) || false"
        />
        <inline-draft-comment-row
          v-if="shouldRenderDraftRow(diffFile.file_hash, line)"
          :key="`draft_${index}`"
          :draft="draftForLine(diffFile.file_hash, line)"
          :diff-file="diffFile"
          :line="line"
        />
      </template>
    </tbody>
  </table>
</template>
