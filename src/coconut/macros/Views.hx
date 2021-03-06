package coconut.macros;

#if macro
import tink.hxx.Parser;
import tink.macro.BuildCache;
import haxe.macro.Context;
import haxe.macro.Expr;

using tink.MacroApi;

class Views {
  static function buildType() 
    return BuildCache.getType('coconut.ui.View', function (ctx:BuildContext):TypeDefinition {
      
      var name = ctx.name,
          type = ctx.type.toComplex();
      
      var ret = 
        switch ctx.type.reduce() {
          case TAnonymous(_):
            macro class $name extends coconut.ui.Renderable {
              public function new(data:tink.state.Observable<$type>, render:$type->vdom.VNode)
                @:pos(ctx.pos) super(tink.state.Observable.auto(function ():vdom.VNode {
                  return render(data);
                }), data);
            }; 
          default:
            macro class $name extends coconut.ui.Renderable {
              public function new(data:$type, render:$type->vdom.VNode)
                @:pos(ctx.pos) super(tink.state.Observable.auto(function ():vdom.VNode {
                  return render(data);
                }), data);
            }; 
        }
          
      switch ctx.type {
        case TInst(_, params), TEnum(_, params), TAbstract(_, params), TType(_, params) if (params.length > 0):
          ret.params = [];
          for (p in params)
            switch p {
              case TInst(_.get() => { name: name, kind: KTypeParameter(constraints) }, []):
                ret.params.push({
                  name: name,
                  constraints: [for (c in constraints) c.toComplex()],
                });
              default:
            }
        default:
      }
      ret.meta = [{ name: ':autoBuild', params: [macro coconut.macros.Views.buildClass()], pos: ctx.pos }];
      
      return ret;
    });

  static function buildClass():Array<Field> {
    return ClassBuilder.run([function (c:ClassBuilder) {
      
      var data =           
        switch c.target.superClass.t.get().constructor.get().type.reduce() {
          case TFun(_[1].t.reduce() => TFun(_[0].t => ret, _), _): ret;
          default: throw "super class constructor has unexpected shape";
        }

      if (!c.target.meta.has(':tink'))
        c.target.meta.add(':tink', [], haxe.macro.Context.currentPos());

      if (c.hasConstructor())
        c.getConstructor().toHaxe().pos.error('Custom constructors not allowed on views');

      c.getConstructor((macro function (data) {
        super(data, render);
      }).getFunction().sure()).publish();

      var states = [];

      for (member in c)
        switch member.extractMeta(':state') {
          case Success(m):

            switch member.getVar(true).sure() {
              case { type: null }: member.pos.error('Field requires type');
              case { expr: null }: member.pos.error('Field requires initial value');
              case { expr: e, type: t }:
                
                member.kind = FProp('get', 'set', t);

                var get = 'get_' + member.name,
                    set = 'set_' + member.name,
                    state = '__coco_${member.name}__';

                states.push(state); 
                for (f in (macro class {
                  @:noCompletion var $state:tink.state.State<$t>;

                  @:noCompletion function $get():$t {
                    if (this.$state == null)
                       this.$state = new tink.state.State($e);
                    return this.$state.value;
                  }

                  @:noCompletion inline function $set(param:$t) {
                    this.$state.set(param);
                    return param;
                  }

                }).fields) c.addMember(f);    
            }
            
          default:
        }

      switch states {
        case []:
        case v:

          var copyStates = [
            for (s in states) macro this.$s = that.$s
          ];
          for (f in (macro class {
            override function update(old:{}, elt:js.html.Element) {
              switch Std.instance(old, $i{c.target.name}) {
                case null:
                case that:
                  $b{copyStates};
              }
              return super.update(old, elt);
            }
          }).fields) c.addMember(f);
      }

      var render = c.memberByName('render').sure();
      var impl = render.getFunction().sure();

      switch impl.args {
        case []:

          impl.args.push({
            name: '__data__',
            type: data.toComplex({ direct: true }),
          });
          
          var statements = [
            if (impl.expr.getString().isSuccess()) 
              macro @:pos(impl.expr.pos) return hxx(${impl.expr});
            else
              impl.expr
          ];

          for (v in data.getFields().sure()) if (v.isPublic) {
            var name = v.name;
            statements.unshift(macro var $name = __data__.$name);
          }

          impl.expr = statements.toBlock(impl.expr.pos);

        case [v]:
          if (v.type == null)
            v.type = data.toComplex();
          else 
            render.pos.getOutcome(v.type.toType(render.pos).sure().isSubTypeOf(data));
        case v: 
          render.pos.error("The render function should have one argument at most");
      }
    }]);
  }
}
#end
