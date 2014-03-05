# encoding: utf-8

# Load all dependencies.
require 'rubygems'
require 'bundler'
require 'rake'
require 'rake/testtask'
require 'rdoc/task'
require 'jeweler'

begin
  Bundler.setup(:default, :development)
rescue Bundler::BundlerError => e
  $stderr.puts e.message
  $stderr.puts "Run `bundle install` to install missing gems"
  exit e.status_code
end

# Gem Specification.
Jeweler::Tasks.new do |gem|
  gem.name = "revac"
  gem.homepage = "http://github.com/ChrisTimperley/RubyREVAC"
  gem.license = "MIT"
  gem.summary = "Implementation of REVAC tuner for meta-heuristics (Relevance Estimation and Value Calibration
of Evolutionary Algorithm Parameters)."
  gem.description = <<-EOF
    An implementation of the REVAC tuner (Relevance Estimation and Value Calibration
of Evolutionary Algorithm Parameters) proposed by V. Nannen and  A.E. Eiben, extended to work with arbitrary meta-heuristics
implemented on arbitrary platforms.
  EOF
  gem.email = "christimperley@gmail.com"
  gem.author = "Chris Timperley"
end

# Gem Management.
Jeweler::RubygemsDotOrgTasks.new

# Unit Testing.
Rake::TestTask.new(:test) do |test|
  test.libs << 'lib' << 'test'
  test.pattern = 'test/**/test_*.rb'
  test.verbose = true
end

# Documentation.
task :default => :test
Rake::RDocTask.new do |rdoc|
  version = File.exist?('VERSION') ? File.read('VERSION') : ""

  rdoc.rdoc_dir = 'rdoc'
  rdoc.title = "revac #{version}"
  rdoc.rdoc_files.include('README*')
  rdoc.rdoc_files.include('lib/**/*.rb')
end
