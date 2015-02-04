module StraightServer
  class Logger < Logmaster

    # inserts a number of blank lines
    def blank_lines(n=1)

      n.times { puts "\n" }

      File.open(StraightServer::Initializer::ConfigDir.path + '/' + Config.logmaster['file'], 'a') do |f|
        n.times do
          f.puts "\n"
        end
      end if Config.logmaster['file']

    end

  end
end
