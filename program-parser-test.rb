require "./parser.rb"
require "./parser_factory.rb"

include BackTrackParser

class PSet
  def initialize(var, val)
    @var = var
    @val = val
  end

  def apply(env)
    
  end
end

class PVal
  def initialize(val)
    @val = val
  end

  def apply(env)
    val
  end
end

class PVar
  def initialize(var)
    @var = var
  end

  def apply(env)
    
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

program_parser = ParserFactory.new.instance_eval do 

  symbol    = rule { term("[-/+/*//]|[@:a-zA-Z]+[0-9]*").>> {|e| e }} 
  eq_m      = rule { term("=")}
  camma     = rule { term("[,]").>> {|e| nil }}
  string_m  = rule { term('"[^"]*"') }
  space_m   = rule { term("[ ]+").>> {|e| nil}}
  space_wild_m  = rule { term("[ ]*").>> {|e| nil}}
  newline_m = rule { term("[\n]+") }
  number_m  = rule { term("[0-9]+").>> {|e| e.to_i }}
  sk        = rule { term("[(]").>> {|e| nil} }
  ek        = rule { term("[)]").>> {|e| nil} }

# 予約語check
  symbol_m = rule { seq(nott?(term("if")),
                        nott?(term("end")),
                        nott?(term("def")), 
                        symbol)}

  skip_m = rule("skip"){
    wild{ choice(space_m, newline_m )}
  }

  get_arg_m = proc { |type_m| 
    seq( sk,
         seq(type_m, space_wild_m, 
             wild {
               seq(space_wild_m,camma, space_wild_m, type_m, space_wild_m).>>{|e|e[3]} }).>> {|e| 
           [e[0]] + e[2]
         }, ek)
  }

  rule("set") { seq(
                    term("set"), 
                    space_m,
                    symbol_m,
                    space_m, 
                    eq_m,
                    space_m, 
                    choice( rules("func_call"), symbol_m, number_m )
                    )
  }

  rule("func_args") { 
    get_arg_m.call(symbol_m)
  }

  rule("func_call_args") {
    get_arg_m.call(
                   proc{
                     choice( rules("func_call"), symbol_m, number_m, string_m)
                   })
  }

  rule("seq_one"){
    seq(space_wild_m, 
        choice(
               rules("set"),
               rules("def"),
               rules("func_call"), 
               symbol_m, 
               number_m
               ),
        space_wild_m)
  }

  rule("sequence"){
    choice(
           seq(
               rules("seq_one"),
               choice(
                      term(";"), 
                      newline_m
                      ), 
               wild{ 
                 rules("sequence")
               }
               ), 
           rules("seq_one")
           )
  }

  # rule("if"){
  #   seq(
  #       term("if")
  #       space_wild_m, choice(sy
        
    
  # }

  
  rule("func_call") {
    seq(
        symbol_m,
        rules("func_call_args")
        )
  }
  
  rule("def") {
    seq( 
        term("def"), space_m, 
        symbol_m, space_wild_m,
        rules("func_args"), 
        space_wild_m, 
        rules("sequence"), 
        space_wild_m, 
        term("end")
        )
  }
  
  rule("loop") { wild{ choice(space_m, newline_m, rules("set"))}}
  self
end

parse_tests=[["func_args", "(sea, fdaf, fda)"], 
             ["func_call_args", "(1, 2, 3, sea, fdaf, fda)"], 
             ["set", "set a = 23"], 
             ["sequence", "set b = 23; set a = b;"], 
             ["func_call", "b(1, 2, 3)"], 
             ["func_call_args", "(1, 2, 3, b(1, 2, b(1, 2, 3)), fdaf, fda)"], 
             ["set", "set a = b(1, 2, 3)"], 
             ["sequence", "set b = 23; set a = b; b(1, 2, 3)"],
             ["def", "def b(a, b, c) b end"], 
             ["def", "def b(a, b, c) set b = 23 end"], 
             ["def", "def c(a, b, c) set b = 23; set a = b;  b(1, 2, 3) end"], 
             ["def", "def c(a, b, c) set b = 23; set a = b;  b(1, 2, 3) ; end"] ]

parse_tests.each do|(type, str)|
  reader = StringScanner.new(str)
  result = program_parser.rules(type).call.parse(reader)
  if result
    p [type, result.act , str]
  else
    p ["not match", type, [type, str]]
  end
end


