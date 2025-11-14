import { Icon } from '@/components/Common/Iconify/icons';
import { Popover, PopoverContent, PopoverTrigger, Button, RadioGroup, Radio } from "@heroui/react";
import { useTranslation } from "react-i18next";
import { RootStore } from "@/store";
import { BlinkoStore } from "@/store/blinkoStore";
import { observer } from "mobx-react-lite";

const SortPop = observer(() => {
  const { t } = useTranslation();
  const blinkoStore = RootStore.Get(BlinkoStore);

  const sortOptions = [
    {
      value: 'createdAt-desc',
      label: t('created-time-desc'),
      sortBy: 'createdAt',
      direction: 'desc'
    },
    {
      value: 'createdAt-asc',
      label: t('created-time-asc'),
      sortBy: 'createdAt',
      direction: 'asc'
    },
    {
      value: 'updatedAt-desc',
      label: t('updated-time-desc'),
      sortBy: 'updatedAt',
      direction: 'desc'
    },
    {
      value: 'updatedAt-asc',
      label: t('updated-time-asc'),
      sortBy: 'updatedAt',
      direction: 'asc'
    },
    {
      value: 'content-asc',
      label: t('title-asc'),
      sortBy: 'content',
      direction: 'asc'
    },
    {
      value: 'content-desc',
      label: t('title-desc'),
      sortBy: 'content',
      direction: 'desc'
    },
  ];

  // Get icon based on current sort direction
  const getSortIcon = () => {
    const config = blinkoStore.noteListSortConfig;
    if (!config || config.direction === 'desc') {
      return 'solar:sort-from-top-to-bottom-bold'; // 降序图标
    }
    return 'solar:sort-from-bottom-to-top-bold'; // 升序图标
  };

  const getCurrentSortValue = () => {
    const config = blinkoStore.noteListSortConfig;
    if (!config) return 'createdAt-desc';
    return `${config.sortBy}-${config.direction}`;
  };

  const handleSortChange = (value: string) => {
    const selectedOption = sortOptions.find(opt => opt.value === value);
    if (selectedOption) {
      console.debug('Sort changed:', selectedOption);
      blinkoStore.noteListSortConfig = {
        sortBy: selectedOption.sortBy,
        direction: selectedOption.direction
      };
      console.debug('New sort config:', blinkoStore.noteListSortConfig);
      // Trigger refresh for all lists
      blinkoStore.noteList.resetAndCall({});
      blinkoStore.blinkoList.resetAndCall({});
      blinkoStore.noteOnlyList.resetAndCall({});
      blinkoStore.todoList.resetAndCall({});
      blinkoStore.archivedList.resetAndCall({});
      blinkoStore.trashList.resetAndCall({});
    }
  };

  return (
    <Popover placement="bottom-start" backdrop="blur">
      <PopoverTrigger>
        <Button isIconOnly size="sm" variant="light">
          <Icon
            className="cursor-pointer text-default-600"
            icon={getSortIcon()}
            width="24"
            height="24"
          />
        </Button>
      </PopoverTrigger>
      <PopoverContent>
        <div className="p-4 flex flex-col gap-4 min-w-[280px]">
          <div className="flex items-center gap-2 mb-2">
            <Icon icon={getSortIcon()} width="24" height="24" />
            <span className="text-sm font-medium">{t('sort-by')}</span>
          </div>

          <RadioGroup
            value={getCurrentSortValue()}
            onValueChange={handleSortChange}
          >
            {sortOptions.map(option => (
              <Radio
                key={option.value}
                value={option.value}
                classNames={{
                  base: "max-w-full",
                  label: "w-full"
                }}
              >
                <span>{option.label}</span>
              </Radio>
            ))}
          </RadioGroup>
        </div>
      </PopoverContent>
    </Popover>
  );
});

export default SortPop;