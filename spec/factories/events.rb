# frozen_string_literal: true

FactoryBot.define do
  factory :event do
    project
    author(factory: :user) { project.creator }
    action { :joined }

    trait(:created)   { action { :created } }
    trait(:updated)   { action { :updated } }
    trait(:closed)    { action { :closed } }
    trait(:reopened)  { action { :reopened } }
    trait(:pushed)    { action { :pushed } }
    trait(:commented) { action { :commented } }
    trait(:merged)    { action { :merged } }
    trait(:joined)    { action { :joined } }
    trait(:left)      { action { :left } }
    trait(:destroyed) { action { :destroyed } }
    trait(:expired)   { action { :expired } }
    trait(:archived)  { action { :archived } }

    factory :closed_issue_event do
      action { :closed }
      target { association(:closed_issue, project: project) }
    end

    factory :wiki_page_event do
      action { :created }
      project { @overrides[:wiki_page]&.container || create(:project, :wiki_repo) }
      target { create(:wiki_page_meta, :for_wiki_page, wiki_page: wiki_page) }

      transient do
        wiki_page { create(:wiki_page, container: project) }
      end
    end

    trait :has_design do
      transient do
        design { create(:design, issue: create(:issue, project: project)) }
      end
    end

    trait :for_design do
      has_design

      transient do
        note { create(:note, author: author, project: project, noteable: design) }
      end

      action { :commented }
      target { note }
    end

    factory :design_event, traits: [:has_design] do
      action { :created }
      target { design }
    end
  end

  factory :push_event, class: 'PushEvent' do
    project factory: :project_empty_repo
    author(factory: :user) { project.creator }
    action { :pushed }
  end

  factory :push_event_payload do
    event
    commit_count { 1 }
    action { :pushed }
    ref_type { :branch }
    ref { 'master' }
    commit_to { '3cdce97ed87c91368561584e7358f4d46e3e173c' }
  end
end
