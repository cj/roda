require "rake"
require "rake/clean"

NAME = 'roda'
VERS = lambda do
  require File.expand_path("../lib/roda/version.rb", __FILE__)
  Roda::RodaVersion
end
CLEAN.include ["#{NAME}-*.gem", "rdoc", "coverage", "www/public/*.html", "www/public/rdoc"]

# Gem Packaging and Release

desc "Packages #{NAME}"
task :package=>[:clean] do |p|
  sh %{gem build #{NAME}.gemspec}
end

### RDoc

RDOC_DEFAULT_OPTS = ["--line-numbers", "--inline-source", '--title', 'Roda: Routing tree web framework']

begin
  gem 'hanna-nouveau'
  RDOC_DEFAULT_OPTS.concat(['-f', 'hanna'])
rescue Gem::LoadError
end

rdoc_task_class = begin
  require "rdoc/task"
  RDoc::Task
rescue LoadError
  require "rake/rdoctask"
  Rake::RDocTask
end

RDOC_OPTS = RDOC_DEFAULT_OPTS + ['--main', 'README.rdoc']
RDOC_FILES = %w"README.rdoc CHANGELOG MIT-LICENSE lib/**/*.rb" + Dir["doc/*.rdoc"] + Dir['doc/release_notes/*.txt']

rdoc_task_class.new do |rdoc|
  rdoc.rdoc_dir = "rdoc"
  rdoc.options += RDOC_OPTS
  rdoc.rdoc_files.add RDOC_FILES
end

rdoc_task_class.new(:website_rdoc) do |rdoc|
  rdoc.rdoc_dir = "www/public/rdoc"
  rdoc.options += RDOC_OPTS
  rdoc.rdoc_files.add RDOC_FILES
end

### Website

desc "Make local version of website"
task :website_base do
  sh %{#{FileUtils::RUBY} www/make_www.rb}
end

desc "Make local version of website, with rdoc"
task :website => [:website_base, :website_rdoc]

desc "Make local version of website"
task :serve => :website do
  sh %{#{FileUtils::RUBY} -C www -S rackup}
end


### Specs

begin
  begin
    # RSpec 1
    require "spec/rake/spectask"
    spec_class = Spec::Rake::SpecTask
    spec_files_meth = :spec_files=
  rescue LoadError
    # RSpec 2
    require "rspec/core/rake_task"
    spec_class = RSpec::Core::RakeTask
    spec_files_meth = :pattern=
  end

  spec = lambda do |name, files, d|
    lib_dir = File.join(File.dirname(File.expand_path(__FILE__)), 'lib')
    ENV['RUBYLIB'] ? (ENV['RUBYLIB'] += ":#{lib_dir}") : (ENV['RUBYLIB'] = lib_dir)

    desc "#{d} with -w, some warnings filtered"
    task "#{name}_w" do
      ENV['RUBYOPT'] ? (ENV['RUBYOPT'] += " -w") : (ENV['RUBYOPT'] = '-w')
      rake = ENV['RAKE'] || "#{FileUtils::RUBY} -S rake"
      sh "#{rake} #{name} 2>&1 | egrep -v \"(spec/.*: warning: (possibly )?useless use of == in void context|: warning: instance variable @.* not initialized|: warning: method redefined; discarding old|: warning: previous definition of)|rspec\""
    end

    desc d
    spec_class.new(name) do |t|
      t.send spec_files_meth, files
      t.spec_opts = ENV["#{NAME.upcase}_SPEC_OPTS"].split if ENV["#{NAME.upcase}_SPEC_OPTS"]
    end
  end

  spec_with_cov = lambda do |name, files, d|
    spec.call(name, files, d)
    desc "#{d} with coverage"
    task "#{name}_cov" do
      ENV['COVERAGE'] = '1'
      Rake::Task[name].invoke
    end
  end
  
  task :default => [:spec]
  spec_with_cov.call("spec", Dir["spec/*_spec.rb"] + Dir["spec/plugin/*_spec.rb"], "Run specs")
rescue LoadError
  task :default do
    puts "Must install rspec to run the default task (which runs specs)"
  end
end

### Other

desc "Print #{NAME} version"
task :version do
  puts VERS.call
end

desc "Start an IRB shell using the extension"
task :irb do
  require 'rbconfig'
  ruby = ENV['RUBY'] || File.join(RbConfig::CONFIG['bindir'], RbConfig::CONFIG['ruby_install_name'])
  irb = ENV['IRB'] || File.join(RbConfig::CONFIG['bindir'], File.basename(ruby).sub('ruby', 'irb'))
  sh %{#{irb} -I lib -r #{NAME}}
end


