require "./parser.rb"
require "./parser_factory.rb"

class Enviroment

  def initialize(parent=nil)
    @parent = parent
    @data = {}
  end

  def define(var, val)
    @data[var] = val
  end

  def set(var, val)
    if @data.has_key?(var)
      @data[var] = val
    else
      if @parent
        @parent.set(var, val)
      else
       #raise exception
        false
      end
    end
  end

  def get(var)
    ret = @data[var]
    if ret
      ret
    else
      if @parent 
        @parent.get(var) 
      else
       #raise exception
        nil 
      end
    end
  end
end

class PDef
  def initialize(var, val)
    @var = var
    @val = val
  end

  def apply(env)
    env.define(@var, @val.apply(env))
  end
end

class PSet
  def initialize(var, val)
    @var = var
    @val = val
  end

  def apply(env)
    env.set(@var, @val.apply(env))
  end
end

class PVal
  def initialize(val)
    @val = val
  end

  def apply(env)
    @val
  end
end

class PSequence
  def initialize(val)
    @val = val
  end

  def apply(env)
    @val.each do 
      @val.apply(env)
    end
  end
end


class PVar
  def initialize(var)
    @var = var
  end

  def apply(env)
    env.get(@var)
  end
end

class PIf
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

class PLambda

  def initialize(args, body)
    @args = args
    @body = body
  end

  def apply(env)
    
  end
end

class PApplication

  def initialize(lam, args, body)
    @lam = lam
    @args = args
    @body = body
  end

  def apply(env)
    
  end
end

program_parser = BackTrackParser::ParserFactory.new.instance_eval do 

  symbol       = rule { term("[-/+/*//]|[@:a-zA-Z]+[0-9]*").>> {|e| e }} 
  eq_m         = rule { term("=")}
  camma        = rule { term("[,]").>> {|e| nil }}
  string_m     = rule { term('"[^"]*"').>>{|e| PVal.new(e) }}
  space_m      = rule { term("[ ]+").>> {|e| nil}}
  space_wild_m = rule { term("[ ]*").>> {|e| nil}}
  newline_m    = rule { term("[\n]+") }
  number_m     = rule { term("[0-9]+").>> {|e| PVal.new(e.to_i) }}
  sk           = rule { term("[(]").>> {|e| nil} }
  ek           = rule { term("[)]").>> {|e| nil} }

  # 予約語check 
  #TODO ifa とかもマッチしなくなる
  symbol_m = rule {
    seq(nott?(term("if")),
        nott?(term("else")), 
        nott?(term("end")),
        nott?(term("def")), 
        nott?(term("set")), 
        nott?(term("fn")), 
        symbol).>> {|e|
      e[5]
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
           wild{ choice(space_m, newline_m )}, 
           space_wild_m
           ).>> { nil}

  }

  get_arg_m = proc { |type_m| 
    seq( sk,
         seq(type_m, rules("skip"), 
             wild {
               seq(rules("skip"), camma, rules("skip"), type_m, rules("skip")).>>{|e|e[3]} }).>> {|e| 
           [e[0]] + e[2]
         }, ek).>> {|e| e[1]}
  }

  rule("set") { seq(
                    term("set"), 
                    space_m,
                    symbol_m,
                    space_wild_m, 
                    eq_m,
                    space_wild_m, 
                    rules("val")
                    ).>> {|e| PSet.new(e[2], e[6])}

  }

  rule("func_args") { 
    get_arg_m.call(symbol_m)
  }

  rule("func_call_args") {
    get_arg_m.call(
                   proc{
                      rules("val")
                   })
  }

  rule("seq_one"){
    seq(rules("skip"), 
        choice(
               rules("set"),
               rules("def"),
               rules("if"), 
               rules("val")
               ),
        rules("skip")).>> {|e| e.find_all{ |e| not e.nil?}}
  }



  rule("sequence_cell"){
    choice(
           seq(
               rules("seq_one"),
               choice(
                      term(";"), 
                      newline_m
                      ), 
               wild{ 
                 rules("sequence_cell")
               }
               ).>> {|e| e[2][0]? e[0] + e[2][0] : e[0]}, 
           seq(
               rules("skip"), 
               rules("seq_one")
               ).>> {|e| e[1] }
           )
  }

  rule("sequence"){
    seq(rules("sequence_cell")).>> {|e|
      e[0].each_with_index do |e2, i|
#         p [i, e2]
      end
      PSequence.new(e[0])
    }
  }

  rule("val"){
    choice(
           rules("func_call"), 
           seq(sk, rules("skip"), rules("comp_rule"), rules("skip"), ek).>> {|e| e[2] }, 
           seq(sk, rules("skip"), rules("val"), rules("skip"), ek).>> {|e| e[2] }, 
           symbol_m.call.>> {|e|PVar.new(e)} , 
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
        ).>> {|e| e.find_all{ |e| not e.nil?}}
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
        ).>> {|e| e.find_all{ |e| not e.nil?}}
  }

  
  rule("func_call") {
    seq(
        symbol_m,
        rules("func_call_args")
        )
  }
  
  rule("def") {
    seq( 
        term("def"), space_m, 
        symbol_m, rules("skip"),  
        rules("func_args"), 
        rules("skip"), 
        rules("sequence"), 
        rules("skip"),  
        term("end")
        ).>> {|e| e.find_all{ |e| not e.nil?}}
  }

  rule("fn") {
    seq( 
        term("fn"),
        rules("skip"),  
        rules("func_args"), 
        rules("skip"), 
        rules("sequence"), 
        rules("skip"),  
        term("end")
        ).>> {|e| e.find_all{ |e| not e.nil?}}
  }

#   rules("sequence").call
  self
end


parse_tests=[["func_args"      , "(sea, fdaf, fda)"], 
             ["func_call_args" , "(1, 2, 3, sea, fdaf, fda)"], 
             ["func_call_args" , "(1, 2, 3, b(1, 2, b(a, b, c)), fdaf, fda)"], 
             ["func_call"      , "b(1, 2, 3)"], 
             ["set"            , "set a = 23"], 
             ["set"            , "set a = b(1, 2, 3)"], 
             ["sequence"       , "set b = 23"],
             ["sequence"       , "set b = 23; set a = b;"], 
             ["sequence"       , "set b = 23; set a = b; b(1, 2, 3)"],
             ["def"            , "def b(a, b, c) b end"], 
             ["def"            , "def b(a, b, c) set b = 23 end"], 
             ["def"            , "def c(a, b, c) set b = 23; set a = b;  b(1, 2, 3) end"], 
             ["def"            , "def c(a, b, c) set b = 23; set a = b;  b(1, 2, 3) ; end"] , 
             ["if"             , "if (c(a, b, c)) set b = 23; set a = b;  b(1, 2, 3) ; else b end"], 
             ["if"             , "if (c(a, b, c)) set b = 23; set a = b;  b(1, 2, 3) ; else b \n end"], 
             ["comp_rule"      , "c(a, b, c) == 23"], 
             ["comp_rule"      , "10 > 2"], 
             ["comp_rule"      , "10  <=  +(a, b)"], 
             ["comp_rule"      , "10  >=  +(a, b)"], 
             ["if"             , "if (c(a, b, c) == (23 == b)) a else b end"], 
             ["if"             , "if (c(a, b, (c == 2)) == (23 == b)) a else b end"], 
             ["set"            , "set v = ((c == 2) == (23 == c(a, b, c)))"],
             ["fn"             , "fn (a, b, c) a(a, b, c) end "]
            ]


parse_tests.each do|(type, str)|
  reader = StringScanner.new(str)
  result = program_parser.rules(type).parse(reader)
  if result
    act = result.act
    p [type, str,act.class, act ]
  else
    p ["### not match!!", type, [str, type]]
  end
end


global_env = Enviroment.new 

PDef.new("a", PVal.new(1)).apply(global_env)
PDef.new("b", PVar.new("a")).apply(global_env)
p global_env

