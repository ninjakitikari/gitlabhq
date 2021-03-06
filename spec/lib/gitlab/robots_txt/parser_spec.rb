# frozen_string_literal: true

require 'fast_spec_helper'
require 'rspec-parameterized'

RSpec.describe Gitlab::RobotsTxt::Parser do
  describe '#disallowed?' do
    subject { described_class.new(content).disallowed?(path) }

    context 'a simple robots.txt file' do
      using RSpec::Parameterized::TableSyntax

      let(:content) do
        <<~TXT
          User-Agent: *
          Disallow: /autocomplete/users
          Disallow: /search
          Disallow: /api
        TXT
      end

      where(:path, :result) do
        '/autocomplete/users' | true
        '/autocomplete/users/a.html' | true
        '/search' | true
        '/search.html' | true
        '/api' | true
        '/api/grapql' | true
        '/api/index.html' | true
        '/projects' | false
      end

      with_them do
        it { is_expected.to eq(result), "#{path} expected to be #{result}" }
      end
    end

    context 'robots.txt file with wildcard' do
      using RSpec::Parameterized::TableSyntax

      let(:content) do
        <<~TXT
          User-Agent: *
          Disallow: /search

          User-Agent: *
          Disallow: /*/*.git
          Disallow: /*/archive/
          Disallow: /*/repository/archive*
        TXT
      end

      where(:path, :result) do
        '/search' | true
        '/namespace/project.git' | true
        '/project/archive/' | true
        '/project/archive/file.gz' | true
        '/project/repository/archive' | true
        '/project/repository/archive.gz' | true
        '/project/repository/archive/file.gz' | true
        '/projects' | false
        '/git' | false
        '/projects/git' | false
      end

      with_them do
        it { is_expected.to eq(result), "#{path} expected to be #{result}" }
      end
    end
  end
end
