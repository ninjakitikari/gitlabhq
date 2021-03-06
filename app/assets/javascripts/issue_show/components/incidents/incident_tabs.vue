<script>
import { GlTab, GlTabs } from '@gitlab/ui';
import DescriptionComponent from '../description.vue';
import HighlightBar from './highlight_bar.vue';
import createFlash from '~/flash';
import { s__ } from '~/locale';
import AlertDetailsTable from '~/vue_shared/components/alert_details_table.vue';

import getAlert from './graphql/queries/get_alert.graphql';

export default {
  components: {
    AlertDetailsTable,
    DescriptionComponent,
    GlTab,
    GlTabs,
    HighlightBar,
  },
  inject: ['fullPath', 'iid'],
  apollo: {
    alert: {
      query: getAlert,
      variables() {
        return {
          fullPath: this.fullPath,
          iid: this.iid,
        };
      },
      update(data) {
        return data?.project?.issue?.alertManagementAlert;
      },
      error() {
        createFlash({
          message: s__('Incident|There was an issue loading alert data. Please try again.'),
        });
      },
    },
  },
  data() {
    return {
      alert: null,
    };
  },
  computed: {
    loading() {
      return this.$apollo.queries.alert.loading;
    },
    alertTableFields() {
      if (this.alert) {
        const { detailsUrl, __typename, ...restDetails } = this.alert;
        return restDetails;
      }
      return null;
    },
  },
};
</script>

<template>
  <div>
    <gl-tabs content-class="gl-reset-line-height" class="gl-mt-n3" data-testid="incident-tabs">
      <gl-tab :title="s__('Incident|Summary')">
        <highlight-bar v-if="alert" :alert="alert" />
        <description-component v-bind="$attrs" />
      </gl-tab>
      <gl-tab v-if="alert" class="alert-management-details" :title="s__('Incident|Alert details')">
        <alert-details-table :alert="alertTableFields" :loading="loading" />
      </gl-tab>
    </gl-tabs>
  </div>
</template>
