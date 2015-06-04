module StraightServer
  class Throttler

    def initialize(gateway_id)
      @id              = "gateway_#{gateway_id}"
      @redis           = StraightServer.redis_connection
      @limit           = Config[:'throttle.requests_limit'].to_i
      @period          = Config[:'throttle.period'].to_i # in seconds
      @ip_ban_duration = Config[:'throttle.ip_ban_duration'].to_i # in seconds
    end

    # @param [String] ip address
    # @return [Boolean|Nil] true if request should be rejected,
    #                       false if request should be served,
    def deny?(ip)
      banned?(ip) || throttled?(ip)
    end

    private

    def throttled?(ip)
      return false if @limit <= 0 || @period <= 0
      key   = throttled_key(ip)
      value = @redis.incr(key)
      @redis.expire key, @period * 2
      if value > @limit
        ban ip
        true
      else
        false
      end
    end

    def banned?(ip)
      return false if @ip_ban_duration <= 0
      value = @redis.get(banned_key(ip)).to_i
      if value > 0
        Time.now.to_i <= value + @ip_ban_duration
      else
        false
      end
    end

    def ban(ip)
      return if @ip_ban_duration <= 0
      @redis.set banned_key(ip), Time.now.to_i, ex: @ip_ban_duration
    end

    def throttled_key(ip)
      "#{Config[:'redis.prefix']}:Throttle:#{@id}:#{@period}_#{@limit}:#{Time.now.to_i / @period}:#{ip}"
    end

    def banned_key(ip)
      "#{Config[:'redis.prefix']}:BannedIP:#{ip}"
    end
  end
end
