#!/usr/bin/env node

/**
 * Example Index Generator
 * 
 * This script scans the examples directory, extracts metadata from each example,
 * and generates index files for each category as well as a main index file.
 * 
 * The script also creates a searchable JSON index that can be used for filtering
 * examples by various metadata attributes.
 * 
 * Usage: node scripts/generate_index.js
 */

const fs = require('fs');
const path = require('path');
const yaml = require('js-yaml');
const marked = require('marked');

// Configuration
const EXAMPLES_DIR = path.join(__dirname, '..', 'examples');
const CATEGORIES = [
  // Problem Domain categories
  'performance-issues',
  'error-detection',
  'security-incidents',
  'resource-optimization',
  
  // Workflow Stage categories
  'incident-detection',
  'root-cause-analysis',
  'remediation',
  'end-to-end'
];
const INDEX_PLACEHOLDER = '<!-- This section will be automatically populated by the index generation script -->';
const OUTPUT_FILE = path.join(__dirname, '..', 'examples', 'examples.json');
const MAIN_INDEX_FILE = path.join(__dirname, '..', 'examples', 'index.md');

// Main function
async function generateIndex() {
  console.log('Generating example index...');
  
  const allExamples = [];
  const categoryCounts = {};
  
  // Process each category
  for (const category of CATEGORIES) {
    const categoryPath = path.join(EXAMPLES_DIR, category);
    const categoryExamples = await processCategory(category, categoryPath);
    allExamples.push(...categoryExamples);
    categoryCounts[category] = categoryExamples.length;
    
    // Update the category index file
    await updateCategoryIndex(category, categoryExamples);
  }
  
  // Generate the main index file
  await generateMainIndex(allExamples, categoryCounts);
  
  // Generate the JSON index for search and filtering
  await generateJsonIndex(allExamples);
  
  console.log(`Index generation complete. Found ${allExamples.length} examples.`);
}

// Process a single category directory
async function processCategory(categoryName, categoryPath) {
  if (!fs.existsSync(categoryPath)) {
    console.warn(`Category directory not found: ${categoryPath}`);
    return [];
  }
  
  const examples = [];
  const entries = fs.readdirSync(categoryPath, { withFileTypes: true });
  
  for (const entry of entries) {
    // Skip index files and non-directories
    if (!entry.isDirectory() || entry.name.startsWith('.')) {
      continue;
    }
    
    const examplePath = path.join(categoryPath, entry.name);
    const example = await processExample(categoryName, entry.name, examplePath);
    
    if (example) {
      examples.push(example);
    }
  }
  
  return examples;
}

// Process a single example directory
async function processExample(categoryName, exampleName, examplePath) {
  const readmePath = path.join(examplePath, 'README.md');
  const metadataPath = path.join(examplePath, 'metadata.yaml');
  
  if (!fs.existsSync(readmePath)) {
    console.warn(`README.md not found for example: ${examplePath}`);
    return null;
  }
  
  // Extract title and description from README
  const readmeContent = fs.readFileSync(readmePath, 'utf8');
  const title = extractTitle(readmeContent) || exampleName;
  const description = extractDescription(readmeContent) || '';
  
  // Extract metadata if available
  let metadata = {};
  if (fs.existsSync(metadataPath)) {
    try {
      metadata = yaml.load(fs.readFileSync(metadataPath, 'utf8')) || {};
    } catch (error) {
      console.warn(`Error parsing metadata for ${examplePath}: ${error.message}`);
    }
  }
  
  // Find related examples based on categories/tags
  const relatedExamples = [];
  if (metadata.categories && Array.isArray(metadata.categories)) {
    // This will be populated later after all examples are processed
  }
  
  return {
    id: exampleName,
    title,
    description,
    category: categoryName,
    path: path.relative(EXAMPLES_DIR, examplePath),
    url: `./${categoryName}/${exampleName}/README.md`,
    relatedExamples,
    ...metadata
  };
}

// Extract title from README content
function extractTitle(content) {
  const match = content.match(/^#\s+(.+)$/m);
  return match ? match[1].trim() : null;
}

// Extract description from README content
function extractDescription(content) {
  // Look for the first paragraph after the title
  const lines = content.split('\n');
  let foundTitle = false;
  let description = '';
  
  for (const line of lines) {
    if (!foundTitle && line.startsWith('# ')) {
      foundTitle = true;
      continue;
    }
    
    if (foundTitle && line.trim() !== '' && !line.startsWith('#')) {
      description = line.trim();
      break;
    }
  }
  
  return description;
}

// Update a category index file with the list of examples
async function updateCategoryIndex(category, examples) {
  const indexPath = path.join(EXAMPLES_DIR, category, 'index.md');
  
  if (!fs.existsSync(indexPath)) {
    console.warn(`Index file not found for category: ${category}`);
    return;
  }
  
  let content = fs.readFileSync(indexPath, 'utf8');
  
  // Generate the examples section
  let examplesSection = '';
  if (examples.length === 0) {
    examplesSection = 'No examples available in this category yet.';
  } else {
    for (const example of examples) {
      examplesSection += `### [${example.title}](./${example.id}/README.md)\n\n`;
      examplesSection += `${example.description}\n\n`;
      
      // Add metadata tags if available
      if (example.categories && example.categories.length > 0) {
        examplesSection += 'Tags: ' + example.categories.map(tag => `\`${tag}\``).join(', ') + '\n\n';
      }
      
      // Add environments if available
      if (example.environments && example.environments.length > 0) {
        examplesSection += 'Environments: ' + example.environments.map(env => `\`${env}\``).join(', ') + '\n\n';
      }
      
      // Add difficulty if available
      if (example.difficulty) {
        examplesSection += `Difficulty: ${example.difficulty}\n\n`;
      }
      
      // Add time required if available
      if (example.time_required) {
        examplesSection += `Time Required: ${example.time_required}\n\n`;
      }
    }
  }
  
  // Replace the placeholder with the generated content
  content = content.replace(INDEX_PLACEHOLDER, examplesSection);
  
  fs.writeFileSync(indexPath, content);
  console.log(`Updated index for category: ${category}`);
}

// Generate the main index file with all examples
async function generateMainIndex(allExamples, categoryCounts) {
  // Update the main index.md file with category counts
  if (fs.existsSync(MAIN_INDEX_FILE)) {
    let content = fs.readFileSync(MAIN_INDEX_FILE, 'utf8');
    
    // Update category counts in the main index
    for (const category of CATEGORIES) {
      const count = categoryCounts[category] || 0;
      const pattern = new RegExp(`(### \\[${category.replace(/-/g, '[-\\s]')}.*?\\].*?)(?:\\(\\d+\\))?`, 'i');
      content = content.replace(pattern, `$1 (${count})`);
    }
    
    // Add a timestamp for when the index was last generated
    const timestamp = new Date().toISOString();
    const timestampPattern = /Last updated: .*$/m;
    if (content.match(timestampPattern)) {
      content = content.replace(timestampPattern, `Last updated: ${timestamp}`);
    } else {
      content += `\n\n---\n\nLast updated: ${timestamp}`;
    }
    
    fs.writeFileSync(MAIN_INDEX_FILE, content);
    console.log(`Updated main index file: ${MAIN_INDEX_FILE}`);
  } else {
    console.warn(`Main index file not found: ${MAIN_INDEX_FILE}`);
  }
}

// Generate the JSON index for search and filtering
async function generateJsonIndex(allExamples) {
  // Process examples to add cross-references
  const processedExamples = addCrossReferences(allExamples);
  
  // Extract unique metadata values for filtering
  const filters = extractFilters(processedExamples);
  
  // Create the final index object
  const index = {
    examples: processedExamples,
    filters,
    lastUpdated: new Date().toISOString()
  };
  
  // Write the full index as JSON for search functionality
  fs.writeFileSync(OUTPUT_FILE, JSON.stringify(index, null, 2));
  console.log(`Generated JSON index: ${OUTPUT_FILE}`);
}

// Add cross-references between related examples
function addCrossReferences(examples) {
  // Create a map of categories/tags to examples
  const tagMap = {};
  
  // First pass: build the tag map
  for (const example of examples) {
    if (example.categories && Array.isArray(example.categories)) {
      for (const tag of example.categories) {
        if (!tagMap[tag]) {
          tagMap[tag] = [];
        }
        tagMap[tag].push(example);
      }
    }
  }
  
  // Second pass: add related examples based on shared tags
  return examples.map(example => {
    const related = new Set();
    
    // Find related examples based on shared tags
    if (example.categories && Array.isArray(example.categories)) {
      for (const tag of example.categories) {
        for (const relatedExample of tagMap[tag] || []) {
          // Don't include the example itself
          if (relatedExample.id !== example.id || relatedExample.category !== example.category) {
            related.add(`${relatedExample.category}/${relatedExample.id}`);
          }
        }
      }
    }
    
    // Add related examples to the example object
    return {
      ...example,
      relatedExamples: Array.from(related).slice(0, 5) // Limit to 5 related examples
    };
  });
}

// Extract unique metadata values for filtering
function extractFilters(examples) {
  const filters = {
    categories: new Set(),
    environments: new Set(),
    difficulties: new Set(),
    tools: new Set()
  };
  
  for (const example of examples) {
    // Extract categories/tags
    if (example.categories && Array.isArray(example.categories)) {
      for (const category of example.categories) {
        filters.categories.add(category);
      }
    }
    
    // Extract environments
    if (example.environments && Array.isArray(example.environments)) {
      for (const env of example.environments) {
        filters.environments.add(env);
      }
    }
    
    // Extract difficulty
    if (example.difficulty) {
      filters.difficulties.add(example.difficulty);
    }
    
    // Extract tools
    if (example.tools && Array.isArray(example.tools)) {
      for (const tool of example.tools) {
        if (typeof tool === 'object' && tool.name) {
          filters.tools.add(tool.name);
        } else if (typeof tool === 'string') {
          filters.tools.add(tool);
        }
      }
    }
  }
  
  // Convert Sets to sorted arrays
  return {
    categories: Array.from(filters.categories).sort(),
    environments: Array.from(filters.environments).sort(),
    difficulties: Array.from(filters.difficulties).sort(),
    tools: Array.from(filters.tools).sort()
  };
}

// Run the script
console.log('Starting index generation...');
console.log('Current directory:', __dirname);
console.log('Examples directory:', EXAMPLES_DIR);
console.log('Output file:', OUTPUT_FILE);

generateIndex().catch(error => {
  console.error('Error generating index:', error);
  process.exit(1);
});