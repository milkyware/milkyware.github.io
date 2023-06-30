---
title: Integrating with Flat Files
header:
  image: '/images/integrating-with-flat-files/header.svg'
category: Integration
---

With integration there is often a need to integrate with ageing, legacy systems. This could be as part of a phased migration to a new system or that the legacy system is bespoke and nothing to replace it with. Whatever the reason, it's common for these older system to have limited interfaces to integrate with and is often **flat file exports**.

Having used **BizTalk Server** for a number of years as my integration platform, one feature that was very useful was the **flat file schema wizard**.

![image1](/images/integrating-with-flat-files/image1.gif)

The wizard scaffolded out an XML schema based on a sample file which could then be used to parse a flat file to XML. I'm now moving away from using BizTalk Server and towards **.NET workers, .NET Web APIs and Azure Functions** for integration. For this post, I want to share a couple of libraries I've used to integrate with both **CSVs** (or other delimited files) and **fixed width** files.

For completeness, there are many **ETL** tools such as: **[Azure Data Factory](https://azure.microsoft.com/en-gb/products/data-factory)** and **[AWS Glue](https://aws.amazon.com/glue/)** which can process flat files, however, these can bring some vendor lock-in.

## Samples

I've also prepared a **[sample test project](https://github.com/milkyware/blog-integrating-with-flat-files)** to demonstrate a few  basic scenarios using these libraries. I'll refer to some snippets in there, as well as some of the sample published by the developers.

## [CSVHelper](https://joshclose.github.io/CsvHelper/)

![image2](/images/integrating-with-flat-files/image2.svg)

**CsvHelper** is a very popular nuget package with over 150M downloads!. It's a very simple package which is a wrapper around **System.IO.TextReader/TextWriter** to parse the records and fields to a class as well as writing objects to a file. By **streaming** the flat file through thr library when using **IO backed** streams such as **FileStream**, the memory footprint is kept small. This is particularly important when working with large batch processes which may have millions of records.

``` csharp
...
using var sr = new StreamReader(stream);
using var csv = new CsvReader(sr, new CsvConfiguration(CultureInfo.InvariantCulture));

while (await csv.ReadAsync())
{
...
}
```

### Configuration

There is also a lot of configuration available for mapping the content of the file to a given class. CsvHelper supports both **[attributes](https://joshclose.github.io/CsvHelper/examples/configuration/attributes/)** ...

``` csharp
[Delimiter(",")]
[CultureInfo("")]  // Set CultureInfo to InvariantCulture
public class Foo
{
    [Name("Identifier")]
    public int Id { get; set; }
    
    [Index(1)]
    public string Name { get; set; }
    ...
}
```

... and **[ClassMaps](https://joshclose.github.io/CsvHelper/examples/configuration/class-maps/)** which allow the mapping definition to be kept separate to your domain model or DTO.

``` csharp
[Delimiter(",")]
public class Customer
{
    public string? Id { get; set; }
    public string? FirstName { get; set; }
}

public class CustomerMap : ClassMap<Customer>
{
    public CustomerMap()
    {
        Map(m => m.Id).Index(1);
        Map(m => m.FirstName).Index(2);
    }
}

void Main()
{
    using var csv = new CsvReader(sr, new CsvConfiguration(CultureInfo.InvariantCulture));
    csv.Context.RegisterClassMap<CustomerMap>();
}
```

### Type Converters

This configuration begins to give some equivalent functionality to what's offered by BizTalk flat file schemas. There are also some default **[type converters](https://joshclose.github.io/CsvHelper/examples/type-conversion/)** bundled with the library which allows values to be parsed/formatted as they are read/written. A example used by the developer is **humanised booleans**:

``` csharp
public class Poll
{
    [BooleanTrueValues("yes")]
    [BooleanFalseValues("no")]
    public bool Answer { get; set; }
}

void Main()
{
    ...
    using (var csv = new CsvReader(reader, CultureInfo.InvariantCulture))
    {
        csv.GetRecords<Poll>();
    }
}
```

A noteworthy configuration attribute is `[Format()]` which allows passing a `.ToString()` format for the member it is decorated on. However, this is currently not implemented in all of the bundled type converters such as **DateTimeConverter**. CsvHelper does offer the ability to develop **[custom type converters](https://joshclose.github.io/CsvHelper/examples/type-conversion/custom-type-converter/)** which could be used to add this support in the mean time.

### Multi Record Types

One scenario I've often needed to handle when importing data is some systems exporting multiple record types as a **single flat file** e.g. in the sample project I've demonstrated a flat file containing **customer and organisation** records.

``` csharp
using var csv = new CsvReader(sr, new CsvConfiguration(CultureInfo.InvariantCulture)
{
    HasHeaderRecord = false
});
csv.Context.RegisterClassMap<CustomerMixedMap>();
csv.Context.RegisterClassMap<OrganisationMixedMap>();

while (await csv.ReadAsync())
{
    switch (csv.GetField(0))
    {
      case "c":
          ...
          break;
      case "o":
          ...
          break;
      default:
          break;
    }
}
```

The configuration for this is the same as parsing a single type of record for a file. The key differences are that typically the **header** will need to be disabled as well as a **switch statement** interrogating an ***identifier*** field to determine what class to parse the record as.

## [FileHelpers](https://www.filehelpers.net/)

![image3](/images/integrating-with-flat-files/image3.png)

### Multi Record Types

## Summary
