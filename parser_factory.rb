require "./parser.rb"
module BackTrackParser
  class ParserFactory

    attr_accessor :rules_set

    def initialize (_parent = nil)
      @parent = _parent
      @rules_set ={}
    end

    def make_match(args)
      top = args.shift
      args.inject(yield(top)) do | acm, e|
        acm - yield(e)
      end
    end

    def term(arg)
      Terminal.new( proc { MatchString.new(arg)} ).setName(arg) 
    end

    def nott?(arg)
      Not.new( proc {NotM.new(arg) })
    end

    def andt?(arg)
      And.new( proc {AndM.new(arg) })
    end

    def seq(*args)
      Seq.new( proc { make_match(args) do |e| SeqCell.new(e) end })
    end

    def choice(*args)
      Choice.new( proc { make_match(args) do |e| ChoiceCell.new(e) end})
    end

    def wild(&block) 
      Wild.new( proc { LoopCell.new(block) })
    end

    def wild_plus(&block) 
      Wild.new( proc { LoopCell.new(block, 1) })
    end

    def rules(name)
      @rules_set[name]
    end

    def rule(name = nil,  &block)
      @rules_set[name] = proc { Rule.new(block).setName(name) }
      @rules_set[name]
    end

  end
end
