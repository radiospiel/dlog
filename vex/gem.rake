def sys(*args)
  STDERR.puts "#{args.join(" ")}"
  system *args
end

namespace :gem do
  task :build => :spec do
    options = []
    sys "gem build .gemspec #{options.join(" ")} && mkdir -p pkg && mv *.gem pkg"
  end

  task :spec do
    File.open ".gemspec", "w" do |file|
      file.write <<-TXT
      require "vex/gem"
      Gem.spec File.dirname(__FILE__)
TXT
    end
  end
  
  task :install => :build do
    file = Dir.glob("pkg/*.gem").sort.last
    sys "sudo gem install #{file}"
  end
  
  task :push => :build do
    file = Dir.glob("pkg/*.gem").sort.last
    puts "To push the gem to gemcutter please run"
    puts
    puts "\tgem push #{file}"
  end
end

desc "Build gem"
# task :gem => %w(test gem:install)
task :gem => %w(gem:install gem:push)
