<script>
import { mapState, mapGetters, mapActions } from 'vuex';
import { modalTypes } from '../constants';
import IdeTreeList from './ide_tree_list.vue';
import Upload from './new_dropdown/upload.vue';
import NewEntryButton from './new_dropdown/button.vue';
import NewModal from './new_dropdown/modal.vue';

export default {
  components: {
    Upload,
    IdeTreeList,
    NewEntryButton,
    NewModal,
  },
  computed: {
    ...mapState(['currentBranchId']),
    ...mapGetters(['currentProject', 'currentTree', 'activeFile', 'getUrlForPath']),
  },
  mounted() {
    if (!this.activeFile) return;

    if (this.activeFile.pending && !this.activeFile.deleted) {
      this.$router.push(this.getUrlForPath(this.activeFile.path), () => {
        this.updateViewer('editor');
      });
    } else if (this.activeFile.deleted) {
      this.resetOpenFiles();
    }
  },
  methods: {
    ...mapActions(['updateViewer', 'createTempEntry', 'resetOpenFiles']),
    createNewFile() {
      this.$refs.newModal.open(modalTypes.blob);
    },
    createNewFolder() {
      this.$refs.newModal.open(modalTypes.tree);
    },
  },
};
</script>

<template>
  <ide-tree-list viewer-type="editor">
    <template #header>
      {{ __('Edit') }}
      <div class="ide-tree-actions ml-auto d-flex">
        <new-entry-button
          :label="__('New file')"
          :show-label="false"
          class="d-flex border-0 p-0 mr-3 qa-new-file"
          icon="doc-new"
          @click="createNewFile()"
        />
        <upload
          :show-label="false"
          class="d-flex mr-3"
          button-css-classes="border-0 p-0"
          @create="createTempEntry"
        />
        <new-entry-button
          :label="__('New directory')"
          :show-label="false"
          class="d-flex border-0 p-0"
          icon="folder-new"
          @click="createNewFolder()"
        />
      </div>
      <new-modal ref="newModal" />
    </template>
  </ide-tree-list>
</template>
