// Example React component to test the Neovim configuration
import React, { useState } from 'react';

// This should get a ✨ marker (optimized)
export function OptimizedComponent({ name }: { name: string }) {
  return <div>Hello {name}!</div>;
}

// This might get a 🚫 marker (not optimized due to state mutation)
export function ProblematicComponent() {
  const [items, setItems] = useState<string[]>([]);
  
  const addItem = (item: string) => {
    // This mutation might prevent optimization
    items.push(item);
    setItems(items);
  };

  return (
    <div>
      {items.map((item, index) => (
        <div key={index}>{item}</div>
      ))}
      <button onClick={() => addItem('new item')}>Add Item</button>
    </div>
  );
}

// Another optimized component
const SimpleArrowComponent = ({ count }: { count: number }) => {
  return <span>Count: {count}</span>;
};

export default SimpleArrowComponent;