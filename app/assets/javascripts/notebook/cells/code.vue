<script>
import CodeOutput from './code/index.vue';
import OutputCell from './output/index.vue';

export default {
  name: 'CodeCell',
  components: {
    CodeOutput,
    OutputCell,
  },
  props: {
    cell: {
      type: Object,
      required: true,
    },
    codeCssClass: {
      type: String,
      required: false,
      default: '',
    },
  },
  computed: {
    rawInputCode() {
      if (this.cell.source && Array.isArray(this.cell.source)) {
        return this.cell.source.join('');
      }

      return this.cell.source || '';
    },
    hasOutput() {
      return this.cell.outputs.length;
    },
    outputs() {
      return this.cell.outputs;
    },
  },
};
</script>

<template>
  <div class="cell">
    <code-output
      :raw-code="rawInputCode"
      :count="cell.execution_count"
      :code-css-class="codeCssClass"
      type="input"
    />
    <output-cell
      v-if="hasOutput"
      :count="cell.execution_count"
      :outputs="outputs"
      :metadata="cell.metadata"
      :code-css-class="codeCssClass"
    />
  </div>
</template>

<style scoped>
.cell {
  flex-direction: column;
}
</style>
