require "../parser.rb"
require "../parser_factory.rb"
require "./program.rb"

program_parser = BackTrackParser::ParserFactory.new.instance_eval do 

  symbol       = rule { term("[@:a-zA-Z]+[0-9]*").>> {|e| e }} 
  eq_m         = rule { term("=")}
  camma        = rule { term("[,]").>> {|e| nil }}
  string_m     = rule { term('"[^"]*"').>>{|e| PVal.new(e) }}
  space_m      = rule { term("[ ]+").>> {|e| nil}}
  space_wild_m = rule { term("[ ]*").>> {|e| nil}}
  newline_m    = rule { term("[\n]+").>> {|e| nil}}
  number_m     = rule { term("[0-9]+|-[0-9]+").>> {|e| PVal.new(e.to_i) }}
  sk           = rule { term("[(]").>> {|e| nil} }
  ek           = rule { term("[)]").>> {|e| nil} }

  # 予約語check 
  #TODO ifx, defx とかもマッチしなくなるのを直す。
  symbol_m = rule("symbol") {
    seq(nott?(term("if")),
        nott?(term("else")), 
        nott?(term("end")),
        nott?(term("def")), 
        nott?(term("set")), 
        nott?(term("fn")), 
        symbol).>> {|e|
      e[6]
    }
  }

  rule("comp"){
    choice(
           term("=="), 
           term("!="), 
           term(">="), 
           term("<="), 
           term(">"), 
           term("<")
           )
  }

  rule("skip"){
    choice(
           wild{
             choice(space_m, newline_m )
           }, 
           space_wild_m
           ).>> { nil}

  }

  get_arg_m = proc { |type_m| 
    seq( sk,
         choice(
         seq(type_m, rules("skip"), 
             wild {
               seq(rules("skip"),
                   camma,
                   rules("skip"),
                   type_m,
                   rules("skip")).>>{|e|e[3]} }).>> {|e| 
                  [e[0]] + e[2]
                }, rules("skip").>>{ |e| [] }
                ), ek).>> {|e| e[1]}
  }

  rule("set") { seq(
                    term("set"), 
                    space_m,
                    rules("symbol").>> {|e| e },
                    space_wild_m, 
                    eq_m,
                    space_wild_m, 
                    rules("val")
                    ).>> {|e| PSet.new(e[2], e[6])}

  }

  rule("func_args") { 
    get_arg_m.call(
                   proc{
                     rules("symbol")
                   })
  }

  rule("func_call_args") {
    get_arg_m.call(
                   proc{
                      rules("val")
                   })
  }

  rule("seq_one"){
    seq(space_wild_m, 
        choice(
               rules("set"),
               rules("def"),
          
               rules("if"), 
               rules("val")
               ),
        space_wild_m).>> {|e| e.compact}
  }

  rule("sequence_cell"){
    choice(
           seq(
               rules("seq_one"),
               wild_plus{
                 choice(
                        term(";"), 
                        space_m, 
                        newline_m
                        )
               }, 
               wild{ 
                 rules("sequence_cell")
               }
               ).>> {|e| e[2][0]? e[0] + e[2][0] : e[0]}, 
           seq(
               space_wild_m, 
               rules("seq_one")
               ).>> {|e| e[1] }
           )
  }

  rule("sequence"){
    choice(
           rules("sequence_cell"), 
           rules("skip").>> {|e| [] } 
           ).>> {|e|
      PSequence.new(e)
    }
  }

  rule("val"){
    choice(
           rules("func_call"), 
           rules("fn"),
           seq(sk, rules("skip"), rules("comp_rule"), rules("skip"), ek).>> {|e| e[2] }, 
           seq(sk, rules("skip"), rules("val"), rules("skip"), ek).>> {|e| e[2] }, 
           rules("symbol").>> {|e|PVar.new(e)} , 
           string_m,
           number_m
           )
  }

  rule("comp_rule"){
    seq(
        rules("val"), 
        space_wild_m, 
        rules("comp"),
        space_wild_m,  
        rules("val")
        ).>> {|e|
      comps = {
        "==" => "eq",
        "!=" => "not_eq", 
        ">" => "large", 
        "<" => "small", 
        ">=" => "large_eq", 
        "<=" => "small_eq"
      }
      PApplication.new(PVar.new(comps[e[2]]) ,[e[0], e[4]])
    }
  }

  rule("if"){
    seq(
        term("if"), 
        rules("skip"), 
        sk,
        rules("skip"), 
        choice(rules("comp_rule"), rules("val")),
        rules("skip"), 
        ek,
        rules("skip"), 
        rules("sequence"), 
        rules("skip"), 
        term("else"), 
        rules("skip"), 
        rules("sequence"),
        rules("skip"), 
        term("end")
        ).>> {|e|
      PIf.new(e[4], e[8], e[12])
    }
  }

  
  rule("func_call") {
    seq(
        rules("symbol"),
        rules("func_call_args").>>{|e| e.compact}
        ).>> {|e| PApplication.new(PVar.new(e[0]) , e[1])}
  }
  
  rule("def") {
    seq( 
        term("def"),
        space_m, 
        rules("symbol"), 
        space_wild_m, 
        eq_m, 
        rules("skip"),  
        choice(
               rules("val"), 
               rules("fn"))
        ).>> {|e| PDef.new(e[2], e[6])}
  }

  rule("fn") {
    seq( 
        term("fn"),
        rules("skip"),  
        rules("func_args").>> {|e| e.compact} , 
        rules("skip"), 
        rules("sequence"), 
        rules("skip"),  
        term("end")
        ).>> {|e| PLambda.new(e[2], e[4])}
  }

#   rules("sequence").call
  self
end


def execute_parse_test(test_parser)
  parse_tests=[
               ["func_args"      , "()"], 
               ["func_args"      , "(sea, fdaf)"], 
               ["func_args"      , "(sea, fdaf, fda)"], 
               ["func_call_args" , "(1, 2, 3, sea, fdaf, fda)"], 
               ["func_call_args" , "(1, 2, 3, b(1, 2, b(a, b, c)), fdaf, fda)"], 
               ["func_call"      , "b(1, 2, 3)"], 
               ["set"            , "set a = 23"], 
               ["set"            , "set a = b(1, 2, 3)"], 
               ["sequence"       , "set b = 23"],
               ["sequence"       , "set b = 23; set a = b;"], 
               ["sequence"       , "set b = 23; set a = b; b(1, 2, 3)"],
               ["if"             , "if (c(a, b, c)) set b = 23; set a = b;  b(1, 2, 3) ; else b end"], 
               ["if"             , "if (c(a, b, c)) set b = 23; set a = b;  b(1, 2, 3) ; else b \n end"], 
               ["comp_rule"      , "c(a, b, c) == 23"], 
               ["comp_rule"      , "10 > 2"], 
               ["comp_rule"      , "10 <= call(a, b)"], 
               ["comp_rule"      , "10 >= call(a, b)"], 
               ["if"             , "if (c(a, b, c) == (23 == b)) a else b end"], 
               ["if"             , "if (c(a, b, (c == 2)) == (23 == b)) a else b end"], 
               ["set"            , "set v = ((c == 2) == (23 == c(a, b, c)))"],
               ["fn"             , "fn (a, b, c) a(a, b, c) end "], 
               ["def"            , "def a = fn (a, b, c) a(a, b, c) end"], 
               ["def"            , "def a = 12"]
              ]

  parse_tests.each do|(type, str)|
    reader = StringScanner.new(str)
    result = test_parser.rules(type).parse(reader)
    if result
      act = result.act
      p [type, str,act.class, act ]
    else
      p ["### not match!!", type, [str, type]]
    end
  end
end

class Eva_lu_tor
  def initialize(parser)
    @parser = parser
    @env = Enviroment.new
    init_enviroment(@env)
  end

  def init_enviroment(env)
    env.define("plus"     , PPrimitive.new { |a, b| a + b })
    env.define("sub"      , PPrimitive.new { |a, b| a - b })
    env.define("p"        , PPrimitive.new { |*a  | p a })
    env.define("eq"       , PPrimitive.new { |a, b| a == b })
    env.define("large"    , PPrimitive.new { |a, b| a > b })
    env.define("small"    , PPrimitive.new { |a, b| a < b })
    env.define("large_eq" , PPrimitive.new { |a, b| a >= b })
    env.define("small_eq" , PPrimitive.new { |a, b| a <= b })
    env.define("not_eq"   , PPrimitive.new { |a, b| a != b })
  end

  def eva_l(code)
    reader = StringScanner.new(code)
    @parser.rules("sequence").parse(reader).act.apply(@env)
  end

  def evalfile(filepath)
    ret = nil 
    open(filepath) do |f|
      ret = eva_l(f.read)
    end
    ret 
  end
end

evalutor = Eva_lu_tor.new(program_parser)

def test
  p evalutor.eva_l("p(1)")
  p evalutor.eva_l("(1==1)")
  p evalutor.eva_l("(1!=1)")

    evalutor.eva_l("def a = 10; def c = 100; plus(a, c)")
  p evalutor.eva_l("def pluss = fn(b, a) plus(a, b) end")
  p evalutor.eva_l("pluss(13, 15)")

    evalutor.eva_l("def plus2 = fn (a) plus(a, 2) end")
  p evalutor.eva_l("plus2(10)")
    evalutor.eva_l("def lamlam = fn (a) fn(b) p(a); plus(a, b) end  end")
    evalutor.eva_l("def lamlam10 = lamlam(10)")
    evalutor.eva_l("def lamlam20 = lamlam(20)")
    evalutor.eva_l("p(lamlam10(10));")
    evalutor.eva_l("p(lamlam20(10));")
end

# execute_parse_test(program_parser)
p evalutor.evalfile("hello.myp")
