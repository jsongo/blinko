import React from 'react';
import {
  DndContext,
  closestCenter,
  KeyboardSensor,
  PointerSensor,
  useSensor,
  useSensors,
  DragEndEvent,
} from '@dnd-kit/core';
import {
  arrayMove,
  SortableContext,
  sortableKeyboardCoordinates,
  horizontalListSortingStrategy,
  useSortable,
} from '@dnd-kit/sortable';
import { CSS } from '@dnd-kit/utilities';
import { FileType } from '../Editor/type';
import { api } from '@/lib/trpc';

type DraggableFileGridProps = {
  files: FileType[];
  preview?: boolean;
  columns?: number;
  onReorder?: (newFiles: FileType[]) => void;
  type: 'image' | 'other';
  className?: string;
  renderItem?: (file: FileType) => React.ReactNode;
};

// Sortable item component
const SortableItem = ({ 
  file, 
  renderItem, 
  disabled 
}: { 
  file: FileType; 
  renderItem?: (file: FileType) => React.ReactNode;
  disabled: boolean;
}) => {
  const {
    attributes,
    listeners,
    setNodeRef,
    transform,
    transition,
    isDragging,
  } = useSortable({ id: file.name, disabled });

  const style = {
    transform: CSS.Transform.toString(transform),
    transition,
    opacity: isDragging ? 0.5 : 1,
  };

  return (
    <div ref={setNodeRef} style={style} {...attributes} {...listeners}>
      {renderItem?.(file)}
    </div>
  );
};

export const DraggableFileGrid = ({
  files,
  preview = false,
  onReorder,
  type,
  className,
  renderItem
}: DraggableFileGridProps) => {
  const sensors = useSensors(
    useSensor(PointerSensor),
    useSensor(KeyboardSensor, {
      coordinateGetter: sortableKeyboardCoordinates,
    })
  );

  const filteredFiles = files.filter(i => i.previewType === type);
  
  const handleDragEnd = async (event: DragEndEvent) => {
    const { active, over } = event;

    if (!over || active.id === over.id) {
      return;
    }

    const oldIndex = filteredFiles.findIndex((file) => file.name === active.id);
    const newIndex = filteredFiles.findIndex((file) => file.name === over.id);

    if (oldIndex === -1 || newIndex === -1) {
      return;
    }

    const reorderedFiles = arrayMove(filteredFiles, oldIndex, newIndex);
    
    const allFiles = Array.from(files);
    const newFiles = allFiles.map(file => {
      if (file.previewType === type) {
        return reorderedFiles.shift() || file;
      }
      return file;
    });

    onReorder?.(newFiles);

    try {
      await api.notes.updateAttachmentsOrder.mutate({
        attachments: newFiles.map((file, index) => ({
          name: file.name,
          sortOrder: index
        }))
      });
    } catch (error) {
      console.error('Failed to update attachments order:', error);
    }
  };

  return (
    <DndContext
      sensors={sensors}
      collisionDetection={closestCenter}
      onDragEnd={handleDragEnd}
    >
      <SortableContext
        items={filteredFiles.map(f => f.name)}
        strategy={horizontalListSortingStrategy}
      >
        <div className={className}>
          {filteredFiles.map((file) => (
            <SortableItem
              key={file.name}
              file={file}
              renderItem={renderItem}
              disabled={preview}
            />
          ))}
        </div>
      </SortableContext>
    </DndContext>
  );
}; 