module Effects
  class Effect
    attr_reader :config

    def initialize(config = {})
      @config = config
    end
  end
end
