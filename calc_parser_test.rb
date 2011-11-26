require "./parser.rb"
require "./parser_factory.rb"

MEMO = {}

module BackTrackParser  
  class M 
    alias_method :old_parse, :parse
    def parse(reader)
      info =  [reader.pos, self.class.name, self.name,  self.match.object_id]
#       p ["IN  >", info]
      temp =reader.pos
      result = old_parse(reader)         
      if self.name
        MEMO[[temp, self.name]]||=[]
        MEMO[[temp, self.name]].push result
      end
      if result
#         MEMO[reader.pos,self.name]= result
#         p ["< OUT", info]
      else
#         p ["< OUT", "not matched", info]
      end
      result
    end
  end
end

include BackTrackParser

calc_parser = ParserFactory.new.instance_eval do 

  logic_m   = rule { term("[-/+/*//]").>>{|e| e.to_sym }}
  space_m   = rule { wild { term("[ \n]+") }.>> {|e| nil}}
  number_m  = rule { term("-[0-9]+|[0-9]+").>> {|e| e.to_i} }
  sk        = rule { term("[(]").>> {|e| nil} }
  ek        = rule { term("[)]").>> {|e| nil} }
  eq        = rule { term("==").>> {|e| e} }
  noteq     = rule { term("!=").>> {|e| e} }

  rule("Compare") { 
    seq(space_m, rules("N"), space_m, choice(eq, noteq), space_m, rules("N"), space_m ).>>{|e|
      e[3] == "==" ? e[1] == e[5] : e[1] != e[5]
    }
  }

  rule("N") { 
    choice(number_m, rules("Group"))
  }
  
  rule("Logic") { 
    seq(space_m, logic_m, space_m, rules("N")).>>{|e|

      e.find_all { |e2| not e2.nil?}
    }
  }
  
  rule("Exp"){
    seq(space_m,  rules("N"), space_m , wild { rules("Logic")}, space_m).>>{ |e|

      rest =(e[3].find_all { |e2| not e2.nil?})
      first = e[1]
#       p ([first]  +  rest)
      ret =rest.inject(first) do |acm, e2|
        acm.send(e2[0], e2[1])
      end
#       p ret
      ret
    }
  }

  rule("Group"){
    seq(sk, choice(rules("Compare"), rules("Exp") ),  ek).>> {|e| 
      e[1]
    }
  }

   rule("Loop") {
    choice( rules("Compare"), rules("Exp"), rules("Group")).>> {|e| 
    e
    }
  }

  rules("Loop")
  self
end


p calc_parser.rules_set.keys
["(1*-2)",
 "1", 
 " (3) * 10 ", 
 " 10 / 10 ", 
 "3 == 3", 
 "(3--3) == 6", 
 "(3-3) ==  0", 
 "(3 == 3)", 
 "(3 + 4) != (3 + 2)", 
 "(3 + 4) == (1 + 2 + 3 + 4)", 
 "(3 + 4) == (7)", 
 "((3 + 4) == (3 + 4)) == ((3 + 4) == (3 + 2))"
].each do |exp|
  reader = StringScanner.new(exp)
  if result = calc_parser.rules("Loop").call.parse(reader)
    p [exp, result.matched.act]
  end
  p reader
end

reader = StringScanner.new("
( 1 + 2 + 3 + 4 + 5 + 6 + 7 + 8 + 9 )
 + 
( 1 + 20 + 2 / 3 ) 
 +  
(1 + 1 + (-2 * (3)) ) 
 + 
(1  + 3 + 100)")

if result = calc_parser.rules("Loop").call.parse(reader)
  p ["result", result.matched.act]
end

# p StringScanner.new("").eos?

