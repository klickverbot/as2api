
xsltproc=xsltproc
docbook_stylesheet=/usr/share/sgml/docbook/stylesheet/xsl/nwalsh/fo/docbook.xsl
java_home=~/opt/j2sdk1.4.2_05
fop=~/incoming/fop-0.20.5/fop.sh
as2api=ruby -w as2api.rb

sources = documenter.rb doc_comment.rb html_output.rb \
          xmlwriter.rb xhtmlwriter.rb \
          parse/lexer.rb parse/parser.rb parse/as_io.rb \
	  api_loader.rb api_model.rb \
          as2api.rb ui/cli.rb
docs_pdf=as2api-documentation.pdf
dist_files = ${sources} ${doc_pdf}
mx_classes=examples/flash_mx_2004_7.2/Classes

version = 0.3

dist_dir = as2api-${version}
tgz_name = ${dist_dir}.tar.gz
w32_dist_dir = as2api-allinone-w32-${version}
zip_name = ${w32_dist_dir}.zip

dist: tgz zip

web-dist: tgz zip
	mkdir -p projects/as2api/releases
	cp ${tgz_name} ${zip_name} projects/as2api/releases
	mkdir -p projects/as2api/examples
	${as2api} --classpath ${mx_classes}:examples/as2lib_0.9/src \
	          --output projects/as2api/examples/as2lib-0.9 \
		  --draw-diagrams \
		  --title "as2lib 0.9" \
		  main.* org.as2lib.*
	${as2api} --classpath ${mx_classes}:examples/enflash-0.3/src/classes \
	          --output projects/as2api/examples/enflash-0.3 \
		  --draw-diagrams \
		  --title "enflash 0.3" \
		  com.asual.*
	${as2api} --classpath ${mx_classes}:examples/Oregano_1.2.0beta1/ \
	          --output projects/as2api/examples/oregano_1.2.0beta1/ \
		  --draw-diagrams \
		  --encoding utf-8 \
		  --title "Oregano 1.2.0beta1" \
		  org.omus.*
	cd projects/as2api && xsltproc ../../../www/project_page.xsl ../../project.xml > index.html
	cp ../www/bif.css projects/as2api

tgz: docs
	mkdir -p ${dist_dir}
	cp --parents ${dist_files} ${doc_pdf} ${dist_dir}
	tar czvf ${tgz_name} ${dist_dir}
	rm -r ${dist_dir}

zip: docs
	mkdir -p ${w32_dist_dir}
	cp as2api.exe ${doc_pdf} ${w32_dist_dir}
	zip -r ${zip_name} ${w32_dist_dir}
	rm -r ${w32_dist_dir}

test:
	ruby -w ts.rb

clean:
	rm -rf ${tgz_name} ${zip_name} ${w32_dist_dir} ${dist_dir}


docs: ${doc_pdf}


as2api-documentation.fo: as2api-documentation.xml
	${xsltproc} --stringparam shade.verbatim 1 \
	            --stringparam fop.extensions 1 \
		    ${docbook_stylesheet} \
		    as2api-documentation.xml \
				> as2api-documentation.fo

${doc_pdf}: as2api-documentation.fo
	JAVA_HOME=${java_home} \
	${fop} as2api-documentation.fo -pdf ${doc_pdf}

# noddy check that running with --help option doesn't complain of missing
# required files,
dist-check: tgz
	rm -rf dist-check-tmp
	mkdir dist-check-tmp
	cd dist-check-tmp && \
	tar xzf ../${tgz_name} && \
	cd ${dist_dir} && \
	ruby -w as2api.rb --help > /dev/null
	rm -r dist-check-tmp
