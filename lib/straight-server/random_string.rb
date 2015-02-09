class String

  def self.random(len)
    s = ""
    while s.length != len do
      s = rand(36**len).to_s(36) 
    end
    s
  end

  def repeat(times)
    result = ""
    times.times { result << self }
    result
  end

end

