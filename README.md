# coconut

A silly quest to find the Holy Grail of UI.

## Models

Coconut picks up the notion of *models* from MVC, which encapsulate the *state* in your business logic and define all operations that may affect it.

```haxe
import tink.pure.List;// <-- just an immutable list
import tink.core.Named;// <-- simple key-value pair
import coconut.data.Model;// <-- this is where magic comes from

class TodoItem implements Model {
  
  @:editable var completed:Bool = @byDefault false;
  @:editable var description:String;

  @:constant var created:Date = @byDefault Date.now();

  static public function create(description:String) 
    return new TodoItem({ description: description });//Constructor is autogenerated

  static public function isActive(item:TodoItem)
    return !item.completed;

  static public function isCompleted(item:TodoItem)
    return item.completed;

}

class TodoList implements Model {

  @:observable var items:List<TodoItem>;

  @:transition function add(description:String) 
    items = items.prepend(TodoItem.create(description));
  
  @:transition function clearCompleted() 
    items = items.filter(i => !i.completed);

}

class TodoFilter implements Model {
  @:constant var options:List<Named<TodoItem->Bool>> = [
    new Named('All', _ => true),
    new Named('Active', TodoItem.isActive),
    new Named('Completed', TodoItem.isCompleted),
  ];

  @:observable var currentFilter:TodoItem->Bool = options.iterator().next().value;

  public function matches(item:TodoItem):Bool
    return currentFilter(item);

  @:transition function toggle(filter:TodoItem->Bool) {
    for (o in options)
      if (o.value == filter) currentFilter = filter;

    throw 'this should not happen';
  }
  
  public function isActive(filter:TodoItem->Bool)
    return filter == currentFilter;
}
```

## Views

```
class TodoItemView extends View<TodoItem> {
  function render(item:TodoItem) '
    <div class="todo-item" data-completed={item.completed}>
      <input type="checkbox" checked={item.completed} onchange={e => item.completed = e.target.checked} />
      <input type="name" value={item.description} onchange={e => item.description = e.target.value} />
    </div>
  '
}

class TodoListView extends View<TodoList, TodoFilter> {
  function render(todos:TodoList, filter:TodoFilter) '
    <div class="todo-list">
      <input type="text" onkeypress={if (event.keyCode == Keyboard.ENTER) { todos.add(event.target.value); event.target.value = "" }}>
      <ol>
        <for {item in todos.items}>
          <if {filter}>
            <TodoItemView {...view} />
          </if>
        </for>
      </ol>
      <menu>
        <span>
          <switch {todos.items.count(TodoItem.isActive)}>
            <case {1}>1 item
            <case $v>$v items
          </switch> left
        </span>
        <for {f in filter.options}>
          <button onclick={filter.toggle(f.value)} data-active={filter.isActive(f.value)}>{f.name}</button>
        </for>
        <if {todos.items.exists(TodoItem.isCompleted)}>
          <button onclick={todos.clearCompleted}>Clear Completed</button>
        </if>
      </menu>
    </div>
  '
}
```