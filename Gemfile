# frozen_string_literal: true

source 'https://rubygems.org'

git_source(:github) { |repo_name| "https://github.com/#{repo_name}" }

# gem 'rails'

gem 'inifile', '~> 3.0'
gem 'octokit', '>= 4.14.6'

group :development, :test do
  gem 'pry'
end

group :test do
  gem 'simplecov', require: false
  gem 'fakefs', require: 'fakefs/safe'
  gem 'rspec'
  gem 'webmock', require: 'webmock/rspec'
end