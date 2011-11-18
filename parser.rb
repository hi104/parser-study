#TODO add EOF match

require "strscan"
module BackTrackParser  
  class C #Cons
    include Enumerable
    attr_accessor :car, :cdr

    def initialize(_car)
      @car = _car
    end

    def + (target)
      @cdr = target
      self
    end

    def each
      c = self
      while c
        yield c.car
        c = c.cdr
      end
    end

    def add_tail(target)
      n = self
      while n.cdr
        n = n.cdr
      end
      n.cdr = target
      self
    end

  end

  class M #Match
    attr_accessor :next_match, :match, :matched, :parser, :value, :name, :action

    def initialize(_match)
      @match = _match
    end

    def +(target)
      @next_match = target
      self
    end

    def setName(_name)
      @name = _name
      self
    end

    def setAction(_action)
      @action = _action
      self
    end

    def >>(&block)
      setAction(block)
    end

    def add_tail(target)
      n = self
      while n.next_match
        n = n.next_match
      end
      n.next_match = target
      self
    end

    alias_method :- , :add_tail

    def matcher
      m = match
      while m.is_a?(Proc) 
        m =  m.call 
      end
      m
    end

    def retcons
      C.new(self)
    end

    def parse(reader)
      _parse(reader)
    end

    def _parse
      "need override me!"
    end
  end

  class SeqCell < M 
    def _parse(reader)
      i = reader.pos
      if @matched = matcher.parse(reader)
        return retcons  unless next_match 
        ret = next_match.parse(reader)
        return retcons + ret if ret
      end
      reader.pos = i
      nil
    end
  end

  class ChoiceCell < M 
    def _parse(reader)
      @matched = matcher.parse(reader)
      if @matched
        retcons
      else
        next_match ? next_match.parse(reader) : nil
      end
    end
  end


  class LoopCell < M 

    attr_accessor :min, :max
    def initialize(_match, _min = nil, _max=nil)
      @min=_min
      @max=_max
      super(_match)
    end

    # def _parse(reader)
    #   if @matched = matcher.parse(reader)
    #     retcons + LoopCell.new(@match, count + 1).parse(reader)
    #   else
    #     retcons
    #   end
    # end

    def loopover?(count)
      return false unless @max
      count > @max 
    end

    def loopshort?(count)
      return false unless @min
      count > @min
    end

    def _parse(reader)
      parser = self
      ret = retcons
      while ret_matched = parser.matcher.parse(reader)
        parser.matched = ret_matched
        ret.add_tail parser.retcons unless self == parser
        return nil if  loopover?(ret.map.length)
        parser = LoopCell.new(@match)
      end
      loopshort?(ret.map.length) ? nil : ret
    end
  end

  class NotM < M 
    def _parse(reader)
      i = reader.pos
      if @matched = matcher.parse(reader)
        reader.pos = i
        nil
      else
        reader.pos = i
        retcons
      end
    end
  end

  class AndM < M 
    def _parse(reader)
      i = reader.pos
      if @matched = matcher.parse(reader)
        reader.pos = i
        retcons
      else
        reader.pos = i
        nil
      end
    end
  end

  class MatchString < M

    def initialize(_match )
      @match = _match
    end

    def _parse(reader)
      @matched = reader.scan(/#{match}/)
      @matched ? self : nil
    end
  end

  class Tag < M
    def _parse(reader)
      (@matched = matcher.parse(reader)) ? self : nil
    end

  end

  module MultResultParser
    def get_results
      @matched.map do |e| e end
    end
    def act
      acts = get_results.map do |e|
        e.matched ? e.matched.act : e.matched
      end

      action ? action.call(acts) : acts
    end
  end

  module SingleResultParser

    def get_results
      if @matched.is_a?(C)
        @matched.car.matched
      else
        @matched
      end
    end

    def act
      if get_results
        action ? action.call(get_results.act) : get_results.act
      end
    end

  end

  class Not < Tag
    include SingleResultParser
  end

  class And < Tag
    include SingleResultParser
  end

  class Terminal < Tag
    include SingleResultParser
    def act
      if get_results
        action ? action.call(get_results.matched) : get_results.matched
      end
    end
  end
  
  class Choice < Tag 
    include SingleResultParser
  end

  class Rule < Tag 
    include SingleResultParser
  end

  class Wild < Tag 
    include MultResultParser
  end

  class Seq < Tag 
    include MultResultParser
  end

end
