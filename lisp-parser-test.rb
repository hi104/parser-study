require "./parser.rb"
require "./parser_factory.rb"

include BackTrackParser

class LispSetq
  def initialize(var, val)
    @var = var
    @val = val
  end

  def apply(env)
    
  end
end

class LispQuote
  def initialize(val)
    @val = val
  end

  def apply(env)
    val
  end
end

class LispVal
  def initialize(val)
    @val = val
  end

  def apply(env)
    val
  end
end

class LispSym
  def initialize(var)
    @var = var
  end

  def apply(env)
    
  end
end

class LispVar
  def initialize(var)
    @var = var
  end

  def apply(env)
    
  end
end

class LispIf
  def initialize(cond, ok, ng)
    @cond = cond
    @ok = ok
    @ng = ng
  end

  def apply(env)
    if @cond.apply(env)
      @ok.apply(env)
    else
      @ng.apply(env)
    end
  end
end

class LispLambda

  def initialize(args, body)
    @args = args
    @body = body
  end

  def apply(env)
    
  end
end

class LispApplication

  def initialize(lam, args, body)
    @lam = lam
    @args = args
    @body = body
  end

  def apply(env)
    
  end
end

lisp_parser = ParserFactory.new.instance_eval do 
  symbol_m  = rule { term("[/+-/*//]|[@:a-z]+[0-9]*").>> {|e| LispSym.new(e) }} 
#   logic_m   = rule { term("[/+-/*//]")}
  quote_m   = rule { term("'") }
  string_m  = rule { term('"[^"]*"') }
  space_m   = rule { term("[ ]+").>> {|e| nil}}
  newline_m = rule { term("[\n]+") }
  number_m  = rule { term("[0-9]+").>> {|e| LispVal.new(e.to_i) }}
  sk        = rule { term("[(]").>> {|e| nil} }
  ek        = rule { term("[)]").>> {|e| nil} }

  seq_m =  rule("seq") { wild { choice( 
                                       symbol_m, 
                                       space_m, 
                                       number_m, 
                                       string_m, 
                                       rules("s_exp"), 
                                       seq( wild{ quote_m },
                                            choice( symbol_m, rules("s_exp"))))
    }.>>{|e|
      e.find_all { |e2| not e2.nil?}
    }
  }

  s_exp =  rule("s_exp") { seq( sk, rules("seq"), ek).>>{ |e|
    e[1]
    }
  }

  s_exp
end

def print_match(ret, indent = 0)
  if [Seq, Wild].include?(ret.class)
    names = ret.get_results.map do |e| 
      print_match(e.matched, indent + 1)
    end
    p [" " * indent,ret.class.name, ret.name]
    names
  elsif [Choice].include?(ret.class)
    p [" " * indent, ret.class.name, ret.name, ret.get_results.class.name]
    print_match(ret.get_results, indent)
  elsif [Rule, Not, Terminal] .include?(ret.class)
    p [" " * indent,ret.class.name, ret.name, ret.get_results.class.name]
    print_match(ret.get_results, indent)
  elsif ret.is_a?(M)
    p [" " * indent, ret.class.name, ret.name, ret.matched]
    print_match(ret.matched, indent)
  else
    p [" " * indent,ret, ret.class.name]
    ret.to_s
  end
end



reader = StringScanner.new(%!(+ 1 2 435 3  '() "afa" (''''plus "afa") )!)

result = lisp_parser.call.parse(reader)
# print_match(result)

puts "result"
p result.act
