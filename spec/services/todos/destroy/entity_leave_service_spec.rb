# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Todos::Destroy::EntityLeaveService do
  let_it_be(:group, reload: true)   { create(:group, :private) }
  let_it_be(:project, reload: true) { create(:project, group: group) }
  let_it_be(:user, reload: true)    { create(:user) }
  let_it_be(:user2, reload: true)   { create(:user) }
  let_it_be(:issue)                 { create(:issue, project: project) }
  let_it_be(:issue_c)               { create(:issue, project: project, confidential: true) }
  let_it_be(:todo_group_user)       { create(:todo, user: user, group: group) }
  let_it_be(:todo_group_user2)      { create(:todo, user: user2, group: group) }

  let(:mr)                  { create(:merge_request, source_project: project) }
  let!(:todo_mr_user)       { create(:todo, user: user, target: mr, project: project) }
  let!(:todo_issue_user)    { create(:todo, user: user, target: issue, project: project) }
  let!(:todo_issue_c_user)  { create(:todo, user: user, target: issue_c, project: project) }
  let!(:todo_issue_c_user2) { create(:todo, user: user2, target: issue_c, project: project) }

  shared_examples 'using different access permissions' do |access_table|
    using RSpec::Parameterized::TableSyntax

    where(:group_access, :project_access, :c_todos, :mr_todos, :method, &access_table)

    with_them do
      before do
        set_access(project, user, project_access) if project_access
        set_access(group, user, group_access) if group_access
      end

      it "#{params[:method].to_s.humanize(capitalize: false)}" do
        send(method)
      end
    end
  end

  shared_examples 'does not remove any todos' do
    it { does_not_remove_any_todos }
  end

  shared_examples 'removes only confidential issues todos' do
    it { removes_only_confidential_issues_todos }
  end

  shared_examples 'removes confidential issues and merge request todos' do
    it { removes_confidential_issues_and_merge_request_todos }
  end

  def does_not_remove_any_todos
    expect { subject }.not_to change { Todo.count }
  end

  def removes_only_confidential_issues_todos
    expect { subject }.to change { Todo.count }.from(6).to(5)
  end

  def removes_confidential_issues_and_merge_request_todos
    expect { subject }.to change { Todo.count }.from(6).to(4)
    expect(user.todos).to match_array([todo_issue_user, todo_group_user])
  end

  def set_access(object, user, access_name)
    case access_name
    when :developer
      object.add_developer(user)
    when :reporter
      object.add_reporter(user)
    when :guest
      object.add_guest(user)
    end
  end

  describe '#execute' do
    describe 'updating a Project' do
      subject { described_class.new(user.id, project.id, 'Project').execute }

      context 'when project is private' do
        context 'when a user leaves a project' do
          it 'removes project todos for the provided user' do
            expect { subject }.to change { Todo.count }.from(6).to(3)

            expect(user.todos).to match_array([todo_group_user])
            expect(user2.todos).to match_array([todo_issue_c_user2, todo_group_user2])
          end
        end

        context 'access permissions' do
          # rubocop:disable RSpec/LeakyConstantDeclaration
          PROJECT_PRIVATE_ACCESS_TABLE =
            lambda do |_|
              [
                # :group_access, :project_access, :c_todos, :mr_todos, :method
                [nil,            :reporter,       :keep,    :keep,     :does_not_remove_any_todos],
                [nil,            :guest,          :delete,  :keep,     :removes_only_confidential_issues_todos],
                [:reporter,      nil,             :keep,    :keep,     :does_not_remove_any_todos],
                [:guest,         nil,             :delete,  :keep,     :removes_only_confidential_issues_todos]
              ]
            end
          # rubocop:enable RSpec/LeakyConstantDeclaration

          it_behaves_like 'using different access permissions', PROJECT_PRIVATE_ACCESS_TABLE
        end
      end

      context 'when project is not private' do
        let_it_be(:group, reload: true)   { create(:group, :internal) }
        let_it_be(:project, reload: true) { create(:project, :internal, group: group) }
        let_it_be(:issue, reload: true)   { create(:issue, project: project) }
        let_it_be(:issue_c, reload: true) { create(:issue, project: project, confidential: true) }

        it 'enqueues the PrivateFeaturesWorker' do
          expect(TodosDestroyer::PrivateFeaturesWorker)
            .to receive(:perform_async).with(project.id, user.id)

          subject
        end

        context 'confidential issues' do
          context 'when a user is not an author of confidential issue' do
            it_behaves_like 'removes only confidential issues todos'
          end

          context 'when a user is an author of confidential issue' do
            before do
              issue_c.update!(author: user)
            end

            it_behaves_like 'does not remove any todos'
          end

          context 'when a user is an assignee of confidential issue' do
            before do
              issue_c.assignees << user
            end

            it_behaves_like 'does not remove any todos'
          end

          context 'access permissions' do
            # rubocop:disable RSpec/LeakyConstantDeclaration
            PROJECT_NOT_PRIVATE_ACCESS_TABLE =
              lambda do |_|
                [
                  # :group_access, :project_access, :c_todos, :mr_todos, :method
                  [nil,            :reporter,       :keep,    :keep,     :does_not_remove_any_todos],
                  [nil,            :guest,          :delete,  :keep,     :removes_only_confidential_issues_todos],
                  [:reporter,      nil,             :keep,    :keep,     :does_not_remove_any_todos],
                  [:guest,         nil,             :delete,  :keep,     :removes_only_confidential_issues_todos],
                  [:reporter,      :guest,          :keep,    :keep,     :does_not_remove_any_todos]
                ]
              end
            # rubocop:enable RSpec/LeakyConstantDeclaration

            it_behaves_like 'using different access permissions', PROJECT_NOT_PRIVATE_ACCESS_TABLE
          end
        end

        context 'feature visibility check' do
          context 'when issues are visible only to project members' do
            before do
              project.project_feature.update!(issues_access_level: ProjectFeature::PRIVATE)
            end

            it 'removes only users issue todos' do
              expect { subject }.to change { Todo.count }.from(6).to(5)
            end
          end
        end
      end
    end

    describe 'updating a Group' do
      subject { described_class.new(user.id, group.id, 'Group').execute }

      context 'when group is private' do
        context 'when a user leaves a group' do
          it 'removes group and subproject todos for the user' do
            expect { subject }.to change { Todo.count }.from(6).to(2)

            expect(user.todos).to be_empty
            expect(user2.todos).to match_array([todo_issue_c_user2, todo_group_user2])
          end
        end

        context 'access permissions' do
          # rubocop:disable RSpec/LeakyConstantDeclaration
          GROUP_PRIVATE_ACCESS_TABLE =
            lambda do |_|
              [
                # :group_access, :project_access, :c_todos, :mr_todos, :method
                [nil,            :reporter,       :keep,    :keep,     :does_not_remove_any_todos],
                [:reporter,      nil,             :keep,    :keep,     :does_not_remove_any_todos]
              ]
            end
          # rubocop:enable RSpec/LeakyConstantDeclaration

          it_behaves_like 'using different access permissions', GROUP_PRIVATE_ACCESS_TABLE
        end

        context 'with nested groups' do
          let(:subgroup) { create(:group, :private, parent: group) }
          let(:subgroup2) { create(:group, :private, parent: group) }
          let(:subproject) { create(:project, group: subgroup) }
          let(:subproject2) { create(:project, group: subgroup2) }

          let!(:todo_subproject_user) { create(:todo, user: user, project: subproject) }
          let!(:todo_subproject2_user) { create(:todo, user: user, project: subproject2) }
          let!(:todo_subgroup_user) { create(:todo, user: user, group: subgroup) }
          let!(:todo_subgroup2_user) { create(:todo, user: user, group: subgroup2) }
          let!(:todo_subproject_user2) { create(:todo, user: user2, project: subproject) }
          let!(:todo_subpgroup_user2)  { create(:todo, user: user2, group: subgroup) }

          context 'when the user is not a member of any groups/projects' do
            it 'removes todos for the user including subprojects todos' do
              expect { subject }.to change { Todo.count }.from(12).to(4)

              expect(user.todos).to be_empty
              expect(user2.todos)
                .to match_array(
                  [todo_issue_c_user2, todo_group_user2, todo_subproject_user2, todo_subpgroup_user2]
                )
            end
          end

          context 'when the user is member of a parent group' do
            before do
              parent_group = create(:group)
              group.update!(parent: parent_group)
              parent_group.add_developer(user)
            end

            it_behaves_like 'does not remove any todos'
          end

          context 'when the user is member of a subgroup' do
            before do
              subgroup.add_developer(user)
            end

            it 'does not remove group and subproject todos' do
              expect { subject }.to change { Todo.count }.from(12).to(7)

              expect(user.todos).to match_array([todo_group_user, todo_subgroup_user, todo_subproject_user])
              expect(user2.todos)
                .to match_array(
                  [todo_issue_c_user2, todo_group_user2, todo_subproject_user2, todo_subpgroup_user2]
                )
            end
          end

          context 'when the user is member of a child project' do
            before do
              subproject.add_developer(user)
            end

            it 'does not remove subproject and group todos' do
              expect { subject }.to change { Todo.count }.from(12).to(7)

              expect(user.todos).to match_array([todo_subgroup_user, todo_group_user, todo_subproject_user])
              expect(user2.todos)
                .to match_array(
                  [todo_issue_c_user2, todo_group_user2, todo_subproject_user2, todo_subpgroup_user2]
                )
            end
          end
        end
      end

      context 'when group is not private' do
        let_it_be(:group, reload: true)   { create(:group, :internal) }
        let_it_be(:project, reload: true) { create(:project, :internal, group: group) }
        let_it_be(:issue, reload: true)   { create(:issue, project: project) }
        let_it_be(:issue_c, reload: true) { create(:issue, project: project, confidential: true) }

        it 'enqueues the PrivateFeaturesWorker' do
          expect(TodosDestroyer::PrivateFeaturesWorker)
            .to receive(:perform_async).with(project.id, user.id)

          subject
        end

        context 'access permissions' do
          # rubocop:disable RSpec/LeakyConstantDeclaration
          GROUP_NOT_PRIVATE_ACCESS_TABLE =
            lambda do |_|
              [
                # :group_access, :project_access, :c_todos, :mr_todos, :method
                [nil,            nil,             :delete,  :keep,     :removes_only_confidential_issues_todos],
                [nil,            :guest,          :delete,  :keep,     :removes_only_confidential_issues_todos],
                [:reporter,      :guest,          :keep,    :keep,     :does_not_remove_any_todos]
              ]
            end
          # rubocop:enable RSpec/LeakyConstantDeclaration

          it_behaves_like 'using different access permissions', GROUP_NOT_PRIVATE_ACCESS_TABLE
        end
      end
    end

    context 'when entity type is not valid' do
      it 'raises an exception' do
        expect { described_class.new(user.id, group.id, 'GroupWrongly').execute }
          .to raise_error(ArgumentError)
      end
    end

    context 'when entity was not found' do
      it 'does not remove any todos' do
        expect { described_class.new(user.id, non_existing_record_id, 'Group').execute }
          .not_to change { Todo.count }
      end
    end
  end
end
