module StraightServer

  class Thread
    def self.new(&block)
      ::Thread.new(&block)
    end
  end

end
