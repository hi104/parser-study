class UnBoundVariableException < Exception; end
class ArgumentsException < Exception; end

class Enviroment

  def initialize(parent=nil)
    @parent = parent
    @data = {}
  end

  def define(var, val)
    @data[var] = val
  end
  
  def extend(_data)
    @data.merge!(_data)
  end

  def set(var, val)
    if @data.has_key?(var)
      @data[var] = val
    else
      if @parent
        @parent.set(var, val)
      else
        raise UnBoundVariableException, "not found #{var}"
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
       raise UnBoundVariableException, "not found #{var}"
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
    ret = nil
    @val.each do |e|
      ret = e.apply(env)
    end
    ret
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
  attr_reader :args, :body, :env

  def initialize(args, body, env = nil)
    @args = args
    @body = body
    @env = env
  end

  def apply(env)
    PLambda.new(@args, @body, env)
  end
end

class PPrimitive
  def initialize(&block)
    @block = block
  end

  def apply(env)
    self
  end

  def call(args)
    @block.call(*args)
  end

end

class PApplication

  def initialize(fn, args)
    @fn = fn
    @args = args
  end

  def apply(env)
    values = @args.map do |e| e.apply(env) end

    func = @fn.apply(env)
    if func.is_a?(PPrimitive)
      func.call(values)
    else
      if (func.args.length != values.length)
        raise ArgumentsException, "require #{func.args.length} arguments but #{values.length}"
      end
      new_env = Enviroment.new(func.env)
      new_env.extend(Hash[[func.args, values].transpose])
      func.body.apply(new_env)
    end
  end
end
