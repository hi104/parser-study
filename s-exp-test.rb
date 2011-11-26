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

set2 = ParserFactory.new.instance_eval do 

  name_m    = rule { term("[@:a-z]+[0-9]*") }
  logic_m   = rule { term("[/+-/*//]").>>{|e| e.to_sym }}
  space_m   = rule { term("[ ]+").>> {|e| nil}}
  newline_m = rule { term("[\n]+") }
  number_m  = rule { term("[0-9]+").>> {|e| e.to_i} }
  sk        = rule { term("[(]").>> {|e| nil} }
  ek        = rule { term("[)]").>> {|e| nil} }
  ssk       = rule { term("\\[").setName("Start Kakko").>> {|e| " StartKakko #{e}"} }
  eek       = rule { term("\\]").setName("End Kakko") }

  N =  rule("N") { 
    choice(S, SS, name_m, space_m, number_m,logic_m, newline_m ).setName("N-Choice")
  }

  S = rule("S"){
    seq(sk, wild{ N }, ek).setName("S-Seq").>> {|e| 
      e[1].find_all { |e| not e.nil?}
    }
  }

  SS = rule("SS") {
    seq(ssk, wild{ N }, eek).setName("SS-Seq").>> { |e|
      e[1].find_all { |e| not e.nil?}
    }
  }

  LoopS = rule("LoopS") { wild{  choice(space_m, newline_m ,S, SS) }.>> {|e| 
      e.find_all { |e| not e.nil?}
    }
  }

  LoopS
end


reader = StringScanner.new("( + - * / )(1) (2) (3) ( [a] (1111 [2222 3333] 3 (4444 0 n jkl ) ) )
( a (1111 2222 3333 3 (4444 0 n jkl ) ) ) (1 2 3)")

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
result = set2.call.parse(reader).matched
structure =  print_match(result)
p structure

def print_struct(struct, indent = 0)
  if struct.is_a?(Array)
    struct.each do | e|
      print_struct(e, indent + 1)
    end
  else
    if struct
      puts (" "*indent) +  struct
    end
  end
end

# print_struct(structure)

p result.act

# MEMO.each do |k, v|
#   p [k, v.map { |e| e.object_id }]
# end
