# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'octokit/version'

Gem::Specification.new do |spec|
  spec.add_development_dependency 'bundler', '>= 1', '< 3'
  spec.add_development_dependency 'vcr', '>= 5.0.0'
  spec.add_development_dependency 'rspec', '>= 3.7.1'
  spec.add_dependency 'octokit', '>= 4.14.0'
  spec.add_dependency 'inifile', '>= 3.0.0'
  spec.authors = ["Thomas Mendoza"]
  spec.description = %q{Test the security of a remote mirror from a git hook}
  spec.email = ['mendoza33@llnl.gov']
  spec.files = %w(README.md secure-mirror.gemspec)
  spec.files += Dir.glob("lib/**/*.rb")
  spec.homepage = ''
  spec.licenses = ['UNLICENSED']
  spec.name = 'secure-mirror'
  spec.require_paths = ['lib']
  spec.required_ruby_version = '>= 2.0.0'
  spec.required_rubygems_version = '>= 1.3.5'
  spec.summary = 'Ruby framework for enforcing security settings on mirrors'
  spec.version = '0.0.1'
end
